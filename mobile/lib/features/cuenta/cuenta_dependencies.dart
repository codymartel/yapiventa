import 'application/eliminar_cuenta.dart';
import 'data/cuenta_auth.dart';
import 'data/eliminar_cuenta_repository.dart';
import 'presentation/providers/eliminar_cuenta_provider.dart';

/// Arma, con Firebase de verdad, el estado de «Eliminar mi cuenta».
EliminarCuentaProvider crearEliminarCuentaProvider({
  required String uid,
  required String? negocioId,
}) {
  final auth = CuentaAuth();
  return EliminarCuentaProvider(
    eliminarCuenta: EliminarCuenta(
      datos: EliminarCuentaRepository(),
      borrarUsuarioDeAcceso: auth.borrarUsuario,
    ),
    auth: auth,
    uid: uid,
    negocioId: negocioId,
  );
}
