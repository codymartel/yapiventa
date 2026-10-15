import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Estado del cuerpo cuando el catálogo de venta no está disponible:
/// mensaje claro y botón Reintentar (nunca un formulario inútil ni un FAB
/// mudo en el origen).
class MensajeCatalogo extends StatelessWidget {
  const MensajeCatalogo({
    super.key,
    required this.mensaje,
    this.detalle,
    this.cargando = false,
    this.onReintentar,
  });

  final String mensaje;
  final String? detalle;
  final bool cargando;
  final Future<void> Function()? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cargando) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
          ],
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 8),
            Text(
              detalle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
          if (onReintentar != null) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => onReintentar!(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reintentar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
