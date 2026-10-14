import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Aviso amarillo NO bloqueante. Invita a migrar, nunca impide guardar.
class AvisoAmarillo extends StatelessWidget {
  const AvisoAmarillo({super.key, required this.mensaje, this.icono});

  final String mensaje;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bordeMedio),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono ?? Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(mensaje, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
