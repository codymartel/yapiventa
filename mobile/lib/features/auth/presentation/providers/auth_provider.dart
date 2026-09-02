import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/auth_repository.dart';
import '../../data/user_repository.dart';

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

  int _bloqueoBoton = 0;
  Timer? _relojTimer;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthStatus get status => _status;
  int get bloqueoBoton => _bloqueoBoton;
  User? get usuarioActual => _repository.usuarioActual;

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

  Future<void> revisarSiYaVerificoEmail() async {
    final user = _repository.usuarioActual;
    if (user == null) return;

    _setLoading(true);
    try {
      final verificado = await _repository.emailEstaVerificado();

      if (verificado) {
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
    } catch (e) {
      _errorMessage = 'No se pudo completar el registro. Intenta de nuevo.';
      _status = AuthStatus.error;
    } finally {
      _setLoading(false);
    }
  }

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
          await _repository.cerrarSesion();
          _errorMessage =
              'Esta cuenta de Google ya está registrada. Inicia sesión.';
          _status = AuthStatus.error;
        } else {
          _status = AuthStatus.success;
        }
      } else {
        if (esModoRegistro) {
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
  // NUEVO — SABER SI EL NEGOCIO YA ESTÁ CONFIGURADO
  // ─────────────────────────────────────────────────────────────────────
  // Este es el método que faltaba y causaba el error de compilación.
  // Consulta el campo `setupComplete` en users/{uid} (false al
  // registrarse, true al terminar el wizard de configuración de
  // negocio) para decidir a dónde navegar tras un login/registro
  // exitoso: '/elegir-rubro' o '/home'.
  Future<bool> negocioYaConfigurado() async {
    final user = _repository.usuarioActual;
    if (user == null) return false;
    return _userRepository.setupCompleto(user.uid);
  }

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

  @override
  void dispose() {
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