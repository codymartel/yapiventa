import '../models/pagina_productos.dart';
import '../models/producto.dart';

abstract class RepositorioProductos {
  Future<PaginaProductos> obtenerPaginaProductos(
    String uid, {
    CursorProductos? despuesDe,
    int limite = 10,
  });

  Future<Producto> crearProducto(String uid, Producto producto);

  Future<String> guardarProducto(String uid, Producto producto);

  Future<void> eliminarProducto(String uid, String productoId);

  Future<void> toggleDisponible(String uid, String productoId, bool disponible);
}
