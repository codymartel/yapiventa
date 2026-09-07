import '../../domain/repositories/repositorio_productos.dart';

class CambiarDisponibilidadProducto {
  final RepositorioProductos _repositorioProductos;

  const CambiarDisponibilidadProducto(this._repositorioProductos);

  Future<void> call({
    required String uid,
    required String productoId,
    required bool disponible,
  }) {
    if (productoId.trim().isEmpty) {
      throw ArgumentError('El producto debe tener un identificador.');
    }
    return _repositorioProductos.toggleDisponible(uid, productoId, disponible);
  }
}
