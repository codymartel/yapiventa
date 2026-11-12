import '../data/eliminar_cuenta_repository.dart';

/// Elimina por completo la cuenta de un vendedor: su negocio, productos,
/// pedidos, resúmenes, gastos de Caja, página pública, plan, perfil y su usuario de acceso.
///
/// Hay que reautenticar al usuario ANTES de llamarlo (Firebase lo exige para
/// borrar un usuario). Se puede repetir: si un intento se corta a medias, el
/// siguiente sigue donde quedó. El usuario de acceso se borra al final para
/// que siempre pueda volver a intentarlo.
///
/// Costo: una sola vez por cuenta, una lectura y un borrado por cada pedido,
/// resumen, gasto y producto del negocio.
class EliminarCuenta {
  final EliminarCuentaRepository _datos;
  final Future<void> Function() _borrarUsuarioDeAcceso;

  EliminarCuenta({required this._datos, required this._borrarUsuarioDeAcceso});

  Future<void> ejecutar({required String uid, String? negocioId}) async {
    final id = negocioId?.trim() ?? '';
    if (id.isNotEmpty) {
      final slug = await _datos.marcarNegocioEnBorrado(id);
      if (slug != null) {
        await _datos.borrarSubcoleccionDelNegocio(id, 'pedidos');
        await _datos.borrarSubcoleccionDelNegocio(id, 'resumenes');
        await _datos.borrarSubcoleccionDelNegocio(id, 'gastos');
        await _datos.borrarSubcoleccionDelNegocio(id, 'productos');
        if (slug.isNotEmpty) await _datos.borrarPaginaPublica(slug);
        await _datos.borrarNegocio(id);
      }
    }
    await _datos.borrarPerfil(uid);
    await _borrarUsuarioDeAcceso();
  }
}
