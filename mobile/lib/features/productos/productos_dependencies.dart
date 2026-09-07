import '../../core/services/cloudinary_service.dart';
import 'application/use_cases/crear_producto.dart';
import 'application/use_cases/editar_producto.dart';
import 'application/use_cases/obtener_pagina_productos.dart';
import 'data/productos_repository.dart';

class ProductosDependencies {
  final ProductosRepository repository;
  final CrearProducto crearProducto;
  final EditarProducto editarProducto;
  final ObtenerPaginaProductos obtenerPaginaProductos;

  const ProductosDependencies({
    required this.repository,
    required this.crearProducto,
    required this.editarProducto,
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
      obtenerPaginaProductos: ObtenerPaginaProductos(repository),
    );
  }
}
