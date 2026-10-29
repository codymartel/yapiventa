import 'dart:typed_data';

import '../../../../core/services/subidor_de_imagenes.dart';
import '../../domain/models/foto_nueva.dart';
import '../../domain/models/producto.dart';
import '../../domain/repositories/repositorio_productos.dart';
import '../services/portada_producto.dart';
import 'subir_fotos_modelos.dart';

class EditarProducto {
  final RepositorioProductos _repositorioProductos;
  final SubidorDeImagenes _subidorDeImagenes;

  const EditarProducto(this._repositorioProductos, this._subidorDeImagenes);

  Future<Producto> call({
    required String uid,
    required String negocioId,
    required Producto producto,
    Uint8List? imagenBytes,
    String? nombreArchivo,
    Map<String, FotoNueva> fotosModelos = const {},
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

    // Sin fotos nuevas de modelos no se espera nada: el guardado sigue igual
    // de directo que antes.
    final modelos = fotosModelos.isEmpty
        ? producto.modelos
        : await subirFotosModelos(
            subidor: _subidorDeImagenes,
            uid: uid,
            modelos: producto.modelos,
            fotos: fotosModelos,
          );

    // Con modelos la portada es la foto del primero (no hay foto principal).
    final portada = PortadaProducto.deModelos(modelos);

    final productoParaGuardar = producto.copyWith(
      modelos: modelos,
      // El negocioId lo aporta quien crea el provider (ya resuelto al iniciar
      // sesión) y se estampa en ProductosRepository sin releer users/{uid}.
      urlImagen: portada?.urlImagen ?? imagenSubida?.url ?? producto.urlImagen,
      cloudinaryPublicId: portada != null
          ? portada.cloudinaryPublicId
          : imagenSubida?.identificador ?? producto.cloudinaryPublicId,
    );

    await _repositorioProductos.guardarProducto(negocioId, productoParaGuardar);
    return productoParaGuardar;
  }
}
