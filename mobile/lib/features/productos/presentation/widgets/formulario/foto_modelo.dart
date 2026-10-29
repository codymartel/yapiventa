import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import 'foto_producto.dart';

/// La foto de un modelo (56 × 56): muestra la nueva, la guardada o una
/// invitación a elegir. Al tocarla abre la galería.
class FotoModelo extends StatelessWidget {
  const FotoModelo({
    super.key,
    required this.fotoNuevaBytes,
    required this.urlImagen,
    required this.habilitada,
    required this.onFotoElegida,
  });

  final Uint8List? fotoNuevaBytes;
  final String urlImagen;
  final bool habilitada;
  final void Function(XFile archivo, Uint8List bytes) onFotoElegida;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Foto del modelo',
      child: GestureDetector(
        onTap: habilitada
            ? () => elegirFotoDeGaleria(context, onFotoElegida)
            : null,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.fondo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bordeSutil),
          ),
          clipBehavior: Clip.antiAlias,
          child: fotoNuevaBytes != null
              ? Image.memory(fotoNuevaBytes!, fit: BoxFit.cover)
              : (urlImagen.isNotEmpty
                    ? Image.network(
                        urlImagen,
                        fit: BoxFit.cover,
                        // Si la foto guardada no carga, se ofrece elegir otra.
                        errorBuilder: (_, _, _) => _invitacion(),
                      )
                    : _invitacion()),
        ),
      ),
    );
  }

  Widget _invitacion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 20,
          color: AppColors.muted,
        ),
        Text('foto *', style: TextStyle(color: AppColors.muted, fontSize: 11)),
      ],
    );
  }
}
