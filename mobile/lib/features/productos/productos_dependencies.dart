import '../../core/services/cloudinary_service.dart';
import '../../core/services/subidor_de_imagenes.dart';
import 'application/use_cases/crear_producto.dart';
import 'data/productos_repository.dart';

class ProductosDependencies {
  final ProductosRepository repository;
  final CrearProducto crearProducto;
  final SubidorDeImagenes subidorDeImagenes;

  const ProductosDependencies({
    required this.repository,
    required this.crearProducto,
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
      subidorDeImagenes: subidorDeImagenes,
    );
  }
}
