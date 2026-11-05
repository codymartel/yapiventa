import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Aviso cuando no se pudo cargar: dice qué pasó y deja reintentar.
class AvisoConexionPedidos extends StatelessWidget {
  const AvisoConexionPedidos({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  });

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: AppColors.texto, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
