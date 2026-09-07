import '../../core/services/cloudinary_service.dart';
import '../../core/services/subidor_de_imagenes.dart';
import 'application/use_cases/crear_producto.dart';
import 'application/use_cases/obtener_pagina_productos.dart';
import 'data/productos_repository.dart';

class ProductosDependencies {
  final ProductosRepository repository;
  final CrearProducto crearProducto;
  final ObtenerPaginaProductos obtenerPaginaProductos;
  final SubidorDeImagenes subidorDeImagenes;

  const ProductosDependencies({
    required this.repository,
    required this.crearProducto,
    required this.obtenerPaginaProductos,
    required this.subidorDeImagenes,
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
      obtenerPaginaProductos: ObtenerPaginaProductos(repository),
      subidorDeImagenes: subidorDeImagenes,
    );
  }
}
