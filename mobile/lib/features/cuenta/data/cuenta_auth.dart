import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/data/google_sign_in_service.dart';

/// Lo que hace falta de Firebase Auth para eliminar una cuenta: volver a
/// comprobar quién es el usuario y borrar su acceso.
class CuentaAuth {
  final FirebaseAuth _auth;
  final GoogleSignInService Function() _crearGoogle;

  CuentaAuth({FirebaseAuth? auth, GoogleSignInService Function()? crearGoogle})
    : _auth = auth ?? FirebaseAuth.instance,
      _crearGoogle = crearGoogle ?? GoogleSignInService.new;

  User get _usuario {
    final usuario = _auth.currentUser;
    if (usuario == null) throw StateError('No hay una sesión iniciada.');
    return usuario;
  }

  /// Entró con correo y contraseña (hay que pedir la contraseña otra vez).
  bool get usaClave =>
      _usuario.providerData.any((p) => p.providerId == 'password');

  Future<void> reautenticarConClave(String clave) {
    final usuario = _usuario;
    return usuario.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: usuario.email ?? '', password: clave),
    );
  }

  /// Muestra el selector de Google. Devuelve false si lo cierra sin elegir.
  Future<bool> reautenticarConGoogle() async {
    final tokens = await _crearGoogle().iniciarSesionConGoogle();
    if (tokens == null) return false;
    await _usuario.reauthenticateWithCredential(
      GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      ),
    );
    return true;
  }

  Future<void> borrarUsuario() => _usuario.delete();

  /// Suelta la cuenta de Google guardada (no es un error si falla).
  Future<void> olvidarGoogle() async {
    try {
      await _crearGoogle().cerrarSesionGoogle();
    } catch (_) {}
  }
}
