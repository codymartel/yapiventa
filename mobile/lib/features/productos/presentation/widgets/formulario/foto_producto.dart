import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';

/// Recuadro de la foto del producto: muestra la foto nueva, la guardada o
/// una invitación a elegir una. Al tocarlo abre la galería.
class FotoProducto extends StatelessWidget {
  const FotoProducto({
    super.key,
    required this.fotoNuevaBytes,
    required this.urlImagenActual,
    required this.habilitada,
    required this.onFotoElegida,
  });

  final Uint8List? fotoNuevaBytes;
  final String urlImagenActual;
  final bool habilitada;
  final void Function(XFile archivo, Uint8List bytes) onFotoElegida;

  Future<void> _elegirFoto(BuildContext context) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: habilitada ? () => _elegirFoto(context) : null,
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
                  : Center(
                      child: Text(
                        'Foto del producto (opcional)\ntoca para elegir',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    )),
      ),
    );
  }
}
