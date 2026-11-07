import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../application/eliminar_cuenta.dart';
import '../../data/cuenta_auth.dart';

/// Estado de la pantalla «Eliminar mi cuenta».
class EliminarCuentaProvider extends ChangeNotifier {
  final EliminarCuenta _eliminarCuenta;
  final CuentaAuth _auth;
  final String uid;
  final String? negocioId;

  bool _trabajando = false;
  String? _error;

  EliminarCuentaProvider({
    required this._eliminarCuenta,
    required this._auth,
    required this.uid,
    required this.negocioId,
  });

  bool get trabajando => _trabajando;
  String? get error => _error;

  /// Se lee una vez, antes de borrar: después ya no hay sesión que preguntar
  /// y el diálogo se sigue redibujando mientras se cierra.
  late final bool usaClave = _auth.usaClave;

  /// Reautentica y borra todo. Devuelve true si la cuenta quedó eliminada.
  /// Si el usuario cierra el selector de Google, no pasa nada (false, sin error).
  Future<bool> eliminar({String clave = ''}) async {
    if (_trabajando) return false;
    _trabajando = true;
    _error = null;
    notifyListeners();
    try {
      if (usaClave) {
        if (clave.isEmpty) {
          _error = 'Escribe tu contraseña para confirmar.';
          return false;
        }
        await _auth.reautenticarConClave(clave);
      } else if (!await _auth.reautenticarConGoogle()) {
        return false;
      }
      await _eliminarCuenta.ejecutar(uid: uid, negocioId: negocioId);
      await _auth.olvidarGoogle();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mensajeDeAuth(e.code);
      return false;
    } catch (_) {
      _error =
          'No se pudo borrar todo. Revisa tu conexión y vuelve a intentarlo: '
          'lo que ya se borró no se repite.';
      return false;
    } finally {
      _trabajando = false;
      notifyListeners();
    }
  }

  String _mensajeDeAuth(String codigo) {
    switch (codigo) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'La contraseña no es correcta.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a confirmar tu identidad e inténtalo otra vez.';
      default:
        return 'No se pudo confirmar tu identidad. Inténtalo de nuevo.';
    }
  }
}
