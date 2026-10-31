import '../../domain/repositories/repositorio_productos.dart';

/// El producto está dentro de un combo: hay que quitarlo de ahí antes.
class ProductoEnComboException implements Exception {
  const ProductoEnComboException(this.nombreCombo);

  final String nombreCombo;
}

class EliminarProducto {
  final RepositorioProductos _repositorioProductos;

  const EliminarProducto(this._repositorioProductos);

  Future<void> call({
    required String negocioId,
    required String productoId,
  }) async {
    if (productoId.trim().isEmpty) {
      throw ArgumentError('El producto debe tener un identificador.');
    }
    final combo = await _repositorioProductos.nombreDelComboQueUsa(
      negocioId,
      productoId,
    );
    if (combo != null) throw ProductoEnComboException(combo);
    await _repositorioProductos.eliminarProducto(negocioId, productoId);
  }
}
