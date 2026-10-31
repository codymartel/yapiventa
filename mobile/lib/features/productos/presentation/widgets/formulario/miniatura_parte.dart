import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// La foto individual de un producto dentro de un combo: una miniatura
/// cuadrada. Sin foto, un icono vacío.
class MiniaturaParte extends StatelessWidget {
  const MiniaturaParte({super.key, required this.url, this.tamano = 40});

  final String url;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.image_outlined, size: 18, color: AppColors.border)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.image_outlined, size: 18, color: AppColors.border),
            ),
    );
  }
}
