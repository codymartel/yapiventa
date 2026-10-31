import '../models/pagina_productos.dart';
import '../models/producto.dart';

abstract class RepositorioProductos {
  Future<PaginaProductos> obtenerPaginaProductos(
    String negocioId, {
    CursorProductos? despuesDe,
    int limite = 10,
  });

  Future<Producto> crearProducto(String negocioId, Producto producto);

  Future<String> guardarProducto(String negocioId, Producto producto);

  Future<void> eliminarProducto(String negocioId, String productoId);

  /// El nombre de un combo que usa este producto, o null si ninguno. Es 1
  /// consulta (límite 1) y sirve para no borrar lo que está dentro de un combo.
  Future<String?> nombreDelComboQueUsa(String negocioId, String productoId);

  Future<void> toggleDisponible(
    String negocioId,
    String productoId,
    bool disponible,
  );
}
