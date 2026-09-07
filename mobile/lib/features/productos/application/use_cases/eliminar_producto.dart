import '../../domain/repositories/repositorio_productos.dart';

class EliminarProducto {
  final RepositorioProductos _repositorioProductos;

  const EliminarProducto(this._repositorioProductos);

  Future<void> call({required String uid, required String productoId}) {
    if (productoId.trim().isEmpty) {
      throw ArgumentError('El producto debe tener un identificador.');
    }
    return _repositorioProductos.eliminarProducto(uid, productoId);
  }
}
