import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/auth_repository.dart';
import '../../data/user_repository.dart';

// ═════════════════════════════════════════════════════════════════════════
// AuthProvider
// ═════════════════════════════════════════════════════════════════════════
// Equivalente a tu AuthViewModel.kt — SOLO la parte de auth pura.
// NO sabe nada de Firebase directamente (eso lo delegan AuthRepository y
// UserRepository). NO sabe nada de widgets, colores, ni Scaffold.
//
// PENDIENTE (marcado también en user_repository.dart): `webActivaInicial`,
// `limiteProductos` y `minimoProductos` van con valores fijos hasta que
// migres features/suscripcion/ y core/config/app_config.dart.
// ═════════════════════════════════════════════════════════════════════════

enum AuthStatus { idle, loading, success, emailNotVerified, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final UserRepository _userRepository;

  AuthProvider({
    AuthRepository? repository,
    UserRepository? userRepository,
  })  : _repository = repository ?? AuthRepository(),
        _userRepository = userRepository ?? UserRepository();

  bool _isLoading = false;
  String? _errorMessage;
  AuthStatus _status = AuthStatus.idle;

  // Equivale a tu `_bloqueoBoton` (StateFlow<Int>). Cuenta los segundos
  // restantes para poder volver a apretar "reenviar correo".
  int _bloqueoBoton = 0;
  Timer? _relojTimer; // equivale a tu `relojJob: Job?`

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthStatus get status => _status;
  int get bloqueoBoton => _bloqueoBoton;
  User? get usuarioActual => _repository.usuarioActual;

  // ─────────────────────────────────────────────────────────────────────
  // LOGIN (email/contraseña)
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `iniciarSesion`. Si el correo no está verificado,
  // manda a emailNotVerified y arranca el reloj de bloqueo — igual que
  // tu Kotlin.
  Future<void> iniciarSesion(String email, String password) async {
    _setLoading(true);
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

  // ─────────────────────────────────────────────────────────────────────
  // REGISTRO (email/contraseña)
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `registrarUsuario`. El manejo de "correo ya existe"
  // vive en auth_repository.dart (registrarse) — aquí solo se reacciona
  // al resultado.
  Future<void> registrarse(String email, String password) async {
    _setLoading(true);
    try {
      await _repository.registrarse(email: email, password: password);
      _status = AuthStatus.emailNotVerified;
      iniciarRelojBloqueo();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mensajeDeError(e);
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // REVISAR SI YA VERIFICÓ EL CORREO
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `revisarSiYaVerificoEmail`. Se llama cuando el usuario
  // aprieta "Ya verifiqué mi correo" en la pantalla de verificación:
  //   1. Le pregunta a AuthRepository si ya está verificado (reload)
  //   2. Si SÍ → crea el perfil con UserRepository y pasa a Success
  //   3. Si NO → vuelve a poner emailNotVerified y reinicia el reloj
  //
  // Este método SOLO existe para el flujo de email — Google nunca pasa
  // por aquí, porque nunca queda en emailNotVerified.
  Future<void> revisarSiYaVerificoEmail() async {
    final user = _repository.usuarioActual;
    if (user == null) return;

    _setLoading(true);
    final verificado = await _repository.emailEstaVerificado();

    if (verificado) {
      // Valores fijos temporales — reemplazar cuando migres
      // suscripcion/ y AppConfig.
      await _userRepository.crearPerfilEnFirestore(
        uid: user.uid,
        email: user.email ?? '',
        webActivaInicial: true,
      );
      await _userRepository.guardarPlanFree(
        uid: user.uid,
        limiteProductos: 20,
        minimoProductos: 1,
      );
      _status = AuthStatus.success;
    } else {
      _errorMessage =
          'Aún no confirmas en Gmail. Espera unos segundos e intenta de nuevo.';
      _status = AuthStatus.emailNotVerified;
      iniciarRelojBloqueo();
    }
    _setLoading(false);
  }

  // ─────────────────────────────────────────────────────────────────────
  // REENVIAR CORREO DE VERIFICACIÓN
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `reenviarEmailDeVerificacion`: llama al repository y
  // arranca el reloj de bloqueo para que no puedan apretar el botón de
  // nuevo antes de tiempo.
  Future<void> reenviarEmailDeVerificacion() async {
    _setLoading(true);
    try {
      await _repository.enviarVerificacionEmail();
      _errorMessage = '¡Correo reenviado! Revisa tu bandeja.';
      iniciarRelojBloqueo();
    } catch (e) {
      _errorMessage = 'Error al reenviar el correo.';
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // GOOGLE — separa login vs registro, igual que tu Kotlin
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `autenticarConGoogle(idToken, esModoRegistro, onExito)`.
  // Con Google NUNCA hay paso de "esperar verificación" (a diferencia
  // del flujo de email) porque Google ya verificó el correo por su
  // cuenta — por eso este método nunca pone AuthStatus.emailNotVerified.
  //
  // Reglas (idénticas a tu Kotlin):
  //   - Modo LOGIN + perfil YA existe        → entra normal (success)
  //   - Modo LOGIN + perfil NO existe        → error "no registrado"
  //   - Modo REGISTRO + perfil NO existe     → crea perfil + plan, entra
  //   - Modo REGISTRO + perfil YA existe     → error "ya registrado"
  //
  // `idToken`/`accessToken` los obtiene quien llame a este método desde
  // el paquete google_sign_in (eso vive en su propio archivo aparte,
  // google_sign_in_service.dart, pendiente de escribir) — este provider
  // no sabe nada de cómo se consiguieron esos tokens.
  Future<void> autenticarConGoogle(
    String idToken,
    String accessToken, {
    required bool esModoRegistro,
  }) async {
    _setLoading(true);
    try {
      final user = await _repository.autenticarConGoogle(idToken, accessToken);
      if (user == null) {
        _errorMessage = 'No se pudo autenticar con Google.';
        _status = AuthStatus.error;
        _setLoading(false);
        return;
      }

      final yaExistePerfil = await _userRepository.existePerfil(user.uid);

      if (yaExistePerfil) {
        if (esModoRegistro) {
          // Alguien intentó "registrarse" con una cuenta de Google que
          // ya tenía perfil → cerrar sesión y avisar que ya existe.
          await _repository.cerrarSesion();
          _errorMessage =
              'Esta cuenta de Google ya está registrada. Inicia sesión.';
          _status = AuthStatus.error;
        } else {
          // Login normal, perfil ya existía → entra.
          _status = AuthStatus.success;
        }
      } else {
        if (esModoRegistro) {
          // Primera vez con Google en modo registro → crea perfil +
          // plan free (mismos valores fijos temporales que en
          // revisarSiYaVerificoEmail).
          await _userRepository.crearPerfilEnFirestore(
            uid: user.uid,
            email: user.email ?? '',
            webActivaInicial: true,
          );
          await _userRepository.guardarPlanFree(
            uid: user.uid,
            limiteProductos: 20,
            minimoProductos: 1,
          );
          _status = AuthStatus.success;
        } else {
          // Alguien intentó iniciar sesión con una cuenta de Google que
          // no tiene perfil todavía → cerrar sesión y pedir que se
          // registre primero.
          await _repository.cerrarSesion();
          _errorMessage = 'Cuenta no registrada. Por favor, regístrate.';
          _status = AuthStatus.error;
        }
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mensajeDeError(e);
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // RELOJ DE BLOQUEO
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `iniciarRelojBloqueo`: cancela el timer anterior si
  // había uno corriendo (igual que tu `relojJob?.cancel()`), pone el
  // contador en 10, y va restando 1 cada segundo con notifyListeners()
  // para que la UI se redibuje y muestre el número bajando.
  void iniciarRelojBloqueo({int segundos = 10}) {
    _relojTimer?.cancel();
    _bloqueoBoton = segundos;
    notifyListeners();

    _relojTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_bloqueoBoton <= 0) {
        timer.cancel();
        return;
      }
      _bloqueoBoton -= 1;
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // CANCELAR REGISTRO
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `cancelarYLimpiarTodo`.
  Future<void> cancelarRegistro() async {
    await _repository.cancelarRegistroSiNoVerificado();
    _relojTimer?.cancel();
    _bloqueoBoton = 0;
    _errorMessage = null;
    _status = AuthStatus.idle;
    notifyListeners();
  }

  void limpiarError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Equivale a tu `override fun onCleared()` — cancela el timer si el
  // provider se destruye, para no dejar un Timer corriendo en el vacío.
  @override
  void dispose() {
    _relojTimer?.cancel();
    super.dispose();
  }

  // Traduce los códigos crípticos de Firebase a mensajes que un usuario
  // real entiende — el equivalente a lo que hacías "a mano" en Kotlin.
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