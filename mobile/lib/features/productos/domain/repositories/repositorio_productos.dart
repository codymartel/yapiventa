import '../models/producto.dart';

abstract class RepositorioProductos {
  Future<Producto> crearProducto(String uid, Producto producto);
}
