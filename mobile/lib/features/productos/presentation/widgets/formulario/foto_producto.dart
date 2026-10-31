import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import '../mosaico_fotos.dart';

/// Reemplaza la galería en las pruebas (el selector real es del sistema).
@visibleForTesting
Future<XFile?> Function()? elegirFotoParaPruebas;

/// Abre la galería y entrega la foto elegida. Lo usan la foto del producto y
/// la de cada modelo.
Future<void> elegirFotoDeGaleria(
  BuildContext context,
  void Function(XFile archivo, Uint8List bytes) onFotoElegida,
) async {
  try {
    final archivo =
        await (elegirFotoParaPruebas?.call() ??
            ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
            ));
    if (archivo == null) return;

    final bytes = await archivo.readAsBytes();
    if (!context.mounted) return;
    onFotoElegida(archivo, bytes);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('No se pudo leer la foto: $e')));
  }
}

/// Recuadro de la foto del producto: muestra la foto nueva, la guardada o
/// una invitación a elegir una. Al tocarlo abre la galería.
class FotoProducto extends StatelessWidget {
  const FotoProducto({
    super.key,
    required this.fotoNuevaBytes,
    required this.urlImagenActual,
    required this.habilitada,
    required this.onFotoElegida,
    this.textoVacio = 'Foto del producto *\ntoca para elegir',
    this.mosaico = const [],
  });

  final Uint8List? fotoNuevaBytes;
  final String urlImagenActual;
  final bool habilitada;
  final void Function(XFile archivo, Uint8List bytes) onFotoElegida;

  /// Lo que se lee cuando todavía no hay foto.
  final String textoVacio;

  /// Las fotos de los productos de un combo: sin foto propia se muestran
  /// juntas como imagen conjunta.
  final List<String> mosaico;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: habilitada
          ? () => elegirFotoDeGaleria(context, onFotoElegida)
          : null,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: fotoNuevaBytes != null
            ? Image.memory(fotoNuevaBytes!, fit: BoxFit.cover)
            : (urlImagenActual.isNotEmpty
                  ? Image.network(urlImagenActual, fit: BoxFit.cover)
                  : (mosaico.isNotEmpty
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              MosaicoFotos(urls: mosaico),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  color: Colors.black54,
                                  child: const Text(
                                    'Imagen conjunta de tus productos · '
                                    'toca para subir una foto propia',
                                    key: Key('imagen-conjunta'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Text(
                              textoVacio,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ))),
      ),
    );
  }
}
