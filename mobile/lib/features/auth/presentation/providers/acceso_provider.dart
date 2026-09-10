import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../../../negocio/domain/repositories/repositorio_progreso_configuracion.dart';
import '../../data/auth_repository.dart';
import '../../data/user_repository.dart';
import 'auth_provider.dart' as app_auth;

enum EstadoAcceso {
  cargandoSesion,
  sinSesion,
  correoNoVerificado,
  cargandoProgreso,
  listo,
  error,
}

class AccesoProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final app_auth.AuthProvider _authProvider;
  final UserRepository _userRepository;
  final RepositorioProgresoConfiguracion _progresoRepository;
  late final StreamSubscription<User?> _authSubscription;

  EstadoAcceso _estado = EstadoAcceso.cargandoSesion;
  ProgresoConfiguracion? _progreso;
  String? _uid;
  String? _email;
  String? _errorMessage;
  Future<void>? _cargaEnCurso;
  int _revisionSesion = 0;
  bool _disposed = false;
  bool _cambioAuthPendiente = false;
  User? _usuarioPendiente;

  factory AccesoProvider({
    required AuthRepository authRepository,
    required app_auth.AuthProvider authProvider,
    required UserRepository userRepository,
    required RepositorioProgresoConfiguracion progresoRepository,
  }) => AccesoProvider._(
    authRepository,
    authProvider,
    userRepository,
    progresoRepository,
  );

  AccesoProvider._(
    this._authRepository,
    this._authProvider,
    this._userRepository,
    this._progresoRepository,
  ) {
    _authProvider.addListener(_cambioDeOperacionAuth);
    _authSubscription = _authRepository.cambiosDeAuth.listen(
      _cambioDeUsuario,
      onError: (_) => _establecerError(),
    );
  }

  EstadoAcceso get estado => _estado;
  ProgresoConfiguracion? get progreso => _progreso;
  String? get uid => _uid;
  String? get email => _email;
  String? get errorMessage => _errorMessage;
  bool get configuracionCompleta => _progreso?.completo ?? false;

  void _cambioDeUsuario(User? usuario) {
    if (_authProvider.isLoading) {
      _cambioAuthPendiente = true;
      _usuarioPendiente = usuario;
      _estado = EstadoAcceso.cargandoSesion;
      _notificar();
      return;
    }
    _procesarUsuario(usuario);
  }

  void _cambioDeOperacionAuth() {
    if (_disposed || _authProvider.isLoading || !_cambioAuthPendiente) return;
    final usuario = _usuarioPendiente;
    _cambioAuthPendiente = false;
    _usuarioPendiente = null;
    _procesarUsuario(usuario);
  }

  void _procesarUsuario(User? usuario) {
    if (usuario != null &&
        usuario.emailVerified &&
        usuario.uid == _uid &&
        _estado == EstadoAcceso.cargandoProgreso &&
        _cargaEnCurso != null) {
      return;
    }
    final revision = ++_revisionSesion;
    _progreso = null;
    _errorMessage = null;
    _uid = usuario?.uid;
    _email = usuario?.email;

    if (usuario == null) {
      _estado = EstadoAcceso.sinSesion;
      _notificar();
      return;
    }
    if (!usuario.emailVerified) {
      _estado = EstadoAcceso.correoNoVerificado;
      _notificar();
      return;
    }
    final carga = _cargarProgreso(usuario, revision);
    _cargaEnCurso = carga;
    carga.whenComplete(() {
      if (identical(_cargaEnCurso, carga)) _cargaEnCurso = null;
    });
  }

  Future<void> recargar() async {
    final cargaActual = _cargaEnCurso;
    if (_estado == EstadoAcceso.cargandoProgreso && cargaActual != null) {
      await cargaActual;
      if (_disposed) return;
    }
    _cambioDeUsuario(_authRepository.usuarioActual);
    final nuevaCarga = _cargaEnCurso;
    if (nuevaCarga != null) await nuevaCarga;
  }

  Future<bool> guardarRubro(String rubro) async {
    final uid = _uid;
    if (uid == null || _estado != EstadoAcceso.listo) return false;
    try {
      await _progresoRepository.guardarRubro(uid, rubro);
      await recargar();
      return _estado == EstadoAcceso.listo;
    } catch (_) {
      _errorMessage = 'No se pudo guardar el rubro. Intenta de nuevo.';
      _notificar();
      return false;
    }
  }

  Future<void> _cargarProgreso(User usuario, int revision) async {
    final uid = usuario.uid;
    _estado = EstadoAcceso.cargandoProgreso;
    _notificar();
    try {
      final existePerfil = await _userRepository.existePerfil(uid);
      if (!_esRespuestaVigente(uid, revision)) return;
      if (!existePerfil) {
        final usaPassword = usuario.providerData.any(
          (proveedor) => proveedor.providerId == EmailAuthProvider.PROVIDER_ID,
        );
        if (!usaPassword) {
          _establecerError(
            'No se encontró un perfil registrado para esta cuenta.',
          );
          return;
        }
      }
      await _userRepository.asegurarPerfilYPlan(
        uid: uid,
        email: usuario.email ?? '',
        webActivaInicial: true,
        limiteProductos: 20,
        minimoProductos: 1,
      );
      if (!_esRespuestaVigente(uid, revision)) return;

      var progreso = await _progresoRepository.obtenerProgresoConfiguracion(
        uid,
      );
      if (!_esRespuestaVigente(uid, revision)) return;

      final faltaConfirmarProductos =
          progreso.completo && !progreso.productosConfirmadosPersistidos;
      if (progreso.completo &&
          (!progreso.setupCompletePersistido || faltaConfirmarProductos)) {
        await _progresoRepository.sincronizarProgresoReconstruido(
          uid,
          setupComplete: progreso.completo,
          confirmarProductos: progreso.completo,
        );
        if (!_esRespuestaVigente(uid, revision)) return;
        progreso = progreso.copyWith(
          setupCompletePersistido: progreso.completo,
          productosConfirmadosPersistidos: progreso.completo,
        );
      }

      _progreso = progreso;
      _estado = EstadoAcceso.listo;
      _errorMessage = null;
      _notificar();
    } catch (_) {
      if (!_esRespuestaVigente(uid, revision)) return;
      _establecerError();
    }
  }

  bool _esRespuestaVigente(String uid, int revision) =>
      !_disposed && _uid == uid && _revisionSesion == revision;

  void _establecerError([String? mensaje]) {
    if (_disposed) return;
    _progreso = null;
    _estado = EstadoAcceso.error;
    _errorMessage =
        mensaje ??
        'No se pudo consultar tu configuración. Revisa tu conexión e intenta de nuevo.';
    _notificar();
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revisionSesion++;
    _authProvider.removeListener(_cambioDeOperacionAuth);
    _authSubscription.cancel();
    super.dispose();
  }
}
