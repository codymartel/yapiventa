import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/auth_repository.dart';
import '../../data/google_sign_in_service.dart';
import '../../data/user_repository.dart';

enum AuthStatus { idle, loading, success, emailNotVerified, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final UserRepository _userRepository;
  final GoogleSignInService _googleSignInService;

  AuthProvider({
    AuthRepository? repository,
    UserRepository? userRepository,
    GoogleSignInService? googleSignInService,
  }) : _repository = repository ?? AuthRepository(),
       _userRepository = userRepository ?? UserRepository(),
       _googleSignInService = googleSignInService ?? GoogleSignInService();

  bool _isLoading = false;
  String? _errorMessage;
  AuthStatus _status = AuthStatus.idle;

  int _bloqueoBoton = 0;
  Timer? _relojTimer;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthStatus get status => _status;
  int get bloqueoBoton => _bloqueoBoton;
  User? get usuarioActual => _repository.usuarioActual;

  Future<void> iniciarSesion(String email, String password) async {
    if (!_iniciarOperacion()) return;
    try {
      await _repository.iniciarSesion(email: email, password: password);

      final verificado = await _repository.emailEstaVerificado();
      if (!verificado) {
        _status = AuthStatus.emailNotVerified;
        iniciarRelojBloqueo();
      } else {
        _status = AuthStatus.success;
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mensajeDeError(e);
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> registrarse(String email, String password) async {
    if (!_iniciarOperacion()) return;
    try {
      final usuario = await _repository.registrarse(
        email: email,
        password: password,
      );
      // El negocio se crea recién cuando el usuario guarda su rubro.
      if (usuario != null) {
        await _aprovisionarPerfil(usuario);
      }
      _status = AuthStatus.emailNotVerified;
      iniciarRelojBloqueo();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mensajeDeError(e);
      _status = AuthStatus.error;
    } catch (_) {
      _errorMessage = 'No se pudo completar el registro. Intenta de nuevo.';
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> revisarSiYaVerificoEmail() async {
    final user = _repository.usuarioActual;
    if (user == null || !_iniciarOperacion()) return;

    try {
      final verificado = await _repository.emailEstaVerificado();

      if (verificado) {
        await _aprovisionarPerfil(user);
        _status = AuthStatus.success;
      } else {
        _errorMessage =
            'Aún no confirmas en Gmail. Espera unos segundos e intenta de nuevo.';
        _status = AuthStatus.emailNotVerified;
        iniciarRelojBloqueo();
      }
    } catch (e) {
      _errorMessage = 'No se pudo completar el registro. Intenta de nuevo.';
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reenviarEmailDeVerificacion() async {
    if (!_iniciarOperacion()) return;
    try {
      await _repository.enviarVerificacionEmail();
      _errorMessage = '¡Correo reenviado! Revisa tu bandeja.';
      _status = AuthStatus.emailNotVerified;
      iniciarRelojBloqueo();
    } catch (e) {
      _errorMessage = 'Error al reenviar el correo.';
      _status = AuthStatus.emailNotVerified;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> autenticarConGoogle(
    String idToken,
    String accessToken, {
    required bool esModoRegistro,
  }) async {
    if (!_iniciarOperacion()) return;
    try {
      final user = await _repository.autenticarConGoogle(idToken, accessToken);
      if (user == null) {
        _errorMessage = 'No se pudo autenticar con Google.';
        _status = AuthStatus.error;
        return;
      }

      final verificado = await _repository.emailEstaVerificado();
      if (!verificado) {
        _status = AuthStatus.emailNotVerified;
        iniciarRelojBloqueo();
        return;
      }

      final yaExistePerfil = await _userRepository.existePerfil(user.uid);

      if (yaExistePerfil) {
        if (esModoRegistro) {
          await _repository.cerrarSesion();
          _errorMessage =
              'Esta cuenta de Google ya está registrada. Inicia sesión.';
          _status = AuthStatus.error;
        } else {
          // LOGIN con cuenta ya registrada: no se escribe nada. El
          // AccesoProvider es quien lee users/{uid}.negocioId y carga el
          // progreso para decidir la ruta.
          _status = AuthStatus.success;
        }
      } else {
        if (esModoRegistro) {
          // Si el perfil no se crea, la cuenta de Firebase queda viva sin
          // users/{uid}. Para un usuario de Google eso no tiene arreglo
          // desde el login, porque el login con Google NO crea perfiles:
          // volvería a caer siempre en "No se encontró un perfil
          // registrado". Se revierte la sesión en vez de dejarla colgada.
          if (!await _aprovisionarYRevierteSiFalla(user)) return;
          _status = AuthStatus.success;
        } else {
          // LOGIN con cuenta NO registrada: Google ya abrió sesión, así que
          // hay que cerrarla para no dejar una sesión sin perfil. No se crea
          // perfil, plan ni negocio — el registro es solo desde
          // RegisterScreen, y desde ahí el mensaje es el inverso.
          await _repository.cerrarSesion();
          _errorMessage =
              'Esta cuenta aún no está registrada. Regístrate para crear tu negocio.';
          _status = AuthStatus.error;
        }
      }
    } catch (e) {
      _errorMessage = e is FirebaseAuthException
          ? _mensajeDeError(e)
          : 'No se pudo completar el acceso con Google.';
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // SABER SI EL NEGOCIO YA ESTÁ CONFIGURADO
  // ─────────────────────────────────────────────────────────────────────
  // Resuelve el estado leyendo `users/{uid}.negocioId` y luego
  // `negocios/{negocioId}.setupComplete` (false al registrarse, true al
  // terminar el wizard de configuración del negocio) para decidir a dónde
  // navegar tras un login/registro exitoso: '/elegir-rubro' o '/home'.
  Future<bool> negocioYaConfigurado() async {
    final user = _repository.usuarioActual;
    if (user == null) return false;
    return _userRepository.setupCompleto(user.uid);
  }

  void iniciarRelojBloqueo({int segundos = 10}) {
    if (_disposed) return;
    _relojTimer?.cancel();
    _bloqueoBoton = segundos;
    _notificar();

    _relojTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_bloqueoBoton <= 0) {
        timer.cancel();
        return;
      }
      _bloqueoBoton -= 1;
      _notificar();
    });
  }

  Future<void> cancelarRegistro() async {
    if (!_iniciarOperacion()) return;
    try {
      await _repository.cancelarRegistroSiNoVerificado();
      _relojTimer?.cancel();
      _bloqueoBoton = 0;
      _errorMessage = null;
      _status = AuthStatus.idle;
    } catch (_) {
      _errorMessage = 'No se pudo cancelar el registro. Intenta de nuevo.';
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cerrarSesion() async {
    if (!_iniciarOperacion()) return;
    try {
      // Primero Firebase: la sesión de la app es la que manda, y ya no
      // debe quedar nadie autenticado aunque el paso siguiente falle.
      await _repository.cerrarSesion();
      await _limpiarSesionGoogle();
      _relojTimer?.cancel();
      _bloqueoBoton = 0;
      _errorMessage = null;
      _status = AuthStatus.idle;
    } catch (_) {
      _errorMessage = 'No se pudo cerrar la sesión. Intenta de nuevo.';
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

  /// Cierra también la sesión de Google para que el próximo
  /// "Continuar con Google" vuelva a mostrar el selector de cuenta en vez
  /// de reutilizar silenciosamente la anterior.
  ///
  /// Va en su propio try/catch a propósito: si Google falla, la sesión de
  /// Firebase ya está cerrada y el usuario sí salió de la app. Reportarlo
  /// como error de "cerrar sesión" sería mentir, y revertir el estado
  /// dejaría al usuario autenticado contra su intención.
  Future<void> _limpiarSesionGoogle() async {
    try {
      await _googleSignInService.cerrarSesionGoogle();
    } catch (_) {
      // Sin efecto: solo se pierde el atajo de la cuenta de Google cacheada.
    }
  }

  void limpiarError() {
    _errorMessage = null;
    _notificar();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _notificar();
  }

  bool _iniciarOperacion() {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    _status = AuthStatus.loading;
    _notificar();
    return true;
  }

  Future<void> _aprovisionarPerfil(User user) {
    return _userRepository.asegurarPerfilYPlan(
      uid: user.uid,
      email: user.email ?? '',
      limiteProductos: 20,
      minimoProductos: 1,
    );
  }

  /// Aprovisiona el perfil de una cuenta NUEVA de Google. Si Firestore
  /// falla, deshace la sesión que Google acaba de abrir —Firebase y Google—
  /// y deja [_errorMessage] con el fallo ORIGINAL de creación del perfil, en
  /// vez de dejar que el `catch` genérico de [autenticarConGoogle] lo
  /// reemplace por "No se pudo completar el acceso con Google".
  ///
  /// Devuelve `true` si el perfil quedó escrito y el flujo puede seguir.
  ///
  /// La limpieza es "best effort": si tampoco se logra cerrar Firebase, el
  /// error que hay que reportar sigue siendo el del perfil, así que nunca
  /// se deja escapar desde acá.
  Future<bool> _aprovisionarYRevierteSiFalla(User user) async {
    try {
      await _aprovisionarPerfil(user);
      return true;
    } catch (e) {
      try {
        await _repository.cerrarSesion();
      } catch (_) {
        // Intentarlo es lo que importa; si falla, el error a reportar
        // continúa siendo el del perfil y no el de la limpieza.
      }
      await _limpiarSesionGoogle();
      _errorMessage = _mensajeDeFalloDePerfil(e);
      _status = AuthStatus.error;
      return false;
    }
  }

  /// Conserva el fallo real de la creación del perfil en vez de taparlo con
  /// un mensaje genérico de Google, que sería engañoso: la autenticación sí
  /// funcionó, lo que falló fue escribir `users/{uid}`.
  String _mensajeDeFalloDePerfil(Object e) {
    if (e is FirebaseAuthException) return _mensajeDeError(e);
    final detalle = e.toString().trim();
    if (detalle.isEmpty) {
      return 'No se pudo crear el perfil de esta cuenta de Google.';
    }
    return 'No se pudo crear el perfil de esta cuenta de Google: $detalle';
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _relojTimer?.cancel();
    super.dispose();
  }

  String _mensajeDeError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'invalid-email':
        return 'El correo no es válido.';
      default:
        return 'Ocurrió un error. Intenta de nuevo.';
    }
  }
}
