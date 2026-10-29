import '../../../../core/services/subidor_de_imagenes.dart';
import '../../domain/models/estructura_producto.dart';
import '../../domain/models/foto_nueva.dart';

/// Sube la foto nueva de cada modelo que la tenga y devuelve los modelos con
/// su url. Los modelos sin foto nueva conservan la que ya tenían. Se sube de
/// una en una: si una falla, el error sube y no se guarda el producto.
Future<List<ModeloProducto>> subirFotosModelos({
  required SubidorDeImagenes subidor,
  required String uid,
  required List<ModeloProducto> modelos,
  required Map<String, FotoNueva> fotos,
}) async {
  if (fotos.isEmpty) return modelos;
  final resultado = <ModeloProducto>[];
  for (final modelo in modelos) {
    final foto = fotos[modelo.id];
    if (foto == null) {
      resultado.add(modelo);
      continue;
    }
    if (foto.nombreArchivo.trim().isEmpty) {
      throw ArgumentError('La imagen debe incluir un nombre de archivo.');
    }
    final subida = await subidor.subir(
      bytes: foto.bytes,
      carpeta: 'usuarios/$uid/productos',
      nombreArchivo: foto.nombreArchivo,
    );
    resultado.add(
      modelo.copyWith(
        urlImagen: subida.url,
        cloudinaryPublicId: subida.identificador,
      ),
    );
  }
  return resultado;
}
