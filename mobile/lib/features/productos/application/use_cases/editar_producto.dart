import 'dart:typed_data';

import '../../../../core/services/subidor_de_imagenes.dart';
import '../../domain/models/producto.dart';
import '../../domain/repositories/repositorio_productos.dart';

class EditarProducto {
  final RepositorioProductos _repositorioProductos;
  final SubidorDeImagenes _subidorDeImagenes;

  const EditarProducto(this._repositorioProductos, this._subidorDeImagenes);

  Future<Producto> call({
    required String uid,
    required Producto producto,
    Uint8List? imagenBytes,
    String? nombreArchivo,
  }) async {
    if (producto.id.trim().isEmpty) {
      throw ArgumentError('El producto debe tener un identificador.');
    }

    ResultadoSubida? imagenSubida;
    if (imagenBytes != null) {
      if (nombreArchivo == null || nombreArchivo.trim().isEmpty) {
        throw ArgumentError('La imagen debe incluir un nombre de archivo.');
      }
      imagenSubida = await _subidorDeImagenes.subir(
        bytes: imagenBytes,
        carpeta: 'usuarios/$uid/productos',
        nombreArchivo: nombreArchivo,
      );
    }

    final productoParaGuardar = producto.copyWith(
      negocioId: uid,
      urlImagen: imagenSubida?.url ?? producto.urlImagen,
      cloudinaryPublicId:
          imagenSubida?.identificador ?? producto.cloudinaryPublicId,
    );

    await _repositorioProductos.guardarProducto(uid, productoParaGuardar);
    return productoParaGuardar;
  }
}
