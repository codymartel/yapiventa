import 'producto.dart';

abstract interface class CursorProductos {}

class PaginaProductos {
  final List<Producto> productos;
  final CursorProductos? ultimoCursor;
  final bool hayMas;

  const PaginaProductos({
    required this.productos,
    required this.ultimoCursor,
    required this.hayMas,
  });
}
