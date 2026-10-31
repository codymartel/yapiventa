import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// La imagen conjunta de un combo: junta las fotos de sus productos en un
/// mosaico (1, 2, 3 o hasta 4). Se arma al mostrarla: no se guarda ningún
/// archivo. Si ninguna parte tiene foto, muestra un icono vacío.
class MosaicoFotos extends StatelessWidget {
  const MosaicoFotos({super.key, required this.urls, this.ajuste});

  final List<String> urls;

  /// Cómo se acomoda cada foto dentro de su cuadro.
  final BoxFit? ajuste;

  /// Cuántas fotos caben en el mosaico.
  static const int maximo = 4;

  @override
  Widget build(BuildContext context) {
    final fotos = [
      for (final url in urls)
        if (url.isNotEmpty) url,
    ].take(maximo).toList();
    if (fotos.isEmpty) {
      return Center(child: Icon(Icons.image_outlined, color: AppColors.border));
    }
    return switch (fotos.length) {
      1 => _foto(fotos[0]),
      2 => Row(
        children: [
          Expanded(child: _foto(fotos[0])),
          const SizedBox(width: 1),
          Expanded(child: _foto(fotos[1])),
        ],
      ),
      3 => Row(
        children: [
          Expanded(child: _foto(fotos[0])),
          const SizedBox(width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _foto(fotos[1])),
                const SizedBox(height: 1),
                Expanded(child: _foto(fotos[2])),
              ],
            ),
          ),
        ],
      ),
      _ => Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _foto(fotos[0])),
                const SizedBox(width: 1),
                Expanded(child: _foto(fotos[1])),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _foto(fotos[2])),
                const SizedBox(width: 1),
                Expanded(child: _foto(fotos[3])),
              ],
            ),
          ),
        ],
      ),
    };
  }

  Widget _foto(String url) => Image.network(
    url,
    fit: ajuste ?? BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, _, _) =>
        Icon(Icons.image_outlined, color: AppColors.border),
  );
}
