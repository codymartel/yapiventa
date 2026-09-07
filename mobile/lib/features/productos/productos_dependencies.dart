import '../../core/services/cloudinary_service.dart';
import 'application/use_cases/crear_producto.dart';
import 'application/use_cases/editar_producto.dart';
import 'application/use_cases/eliminar_producto.dart';
import 'application/use_cases/obtener_pagina_productos.dart';
import 'data/productos_repository.dart';

class ProductosDependencies {
  final ProductosRepository repository;
  final CrearProducto crearProducto;
  final EditarProducto editarProducto;
  final EliminarProducto eliminarProducto;
  final ObtenerPaginaProductos obtenerPaginaProductos;

  const ProductosDependencies({
    required this.repository,
    required this.crearProducto,
    required this.editarProducto,
    required this.eliminarProducto,
    required this.obtenerPaginaProductos,
  });

  factory ProductosDependencies.production() {
    final repository = ProductosRepository();
    final subidorDeImagenes = CloudinaryService();
    return ProductosDependencies(
      repository: repository,
      crearProducto: CrearProducto(
        repositorioProductos: repository,
        subidorDeImagenes: subidorDeImagenes,
      ),
      editarProducto: EditarProducto(repository, subidorDeImagenes),
      eliminarProducto: EliminarProducto(repository),
      obtenerPaginaProductos: ObtenerPaginaProductos(repository),
    );
  }
}
