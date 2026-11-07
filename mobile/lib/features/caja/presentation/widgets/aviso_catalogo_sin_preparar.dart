import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/preparacion_catalogo_provider.dart';

/// El aviso ámbar que queda fijo en Caja si el vendedor eligió «Más tarde»
/// (maqueta B10, pantalla 6): dice qué límites tiene Caja mientras tanto y
/// ofrece prepararlo cuando quiera. No bloquea vender. Si el catálogo ya está
/// preparado (o todavía no se sabe), no ocupa lugar.
class AvisoCatalogoSinPreparar extends StatelessWidget {
  const AvisoCatalogoSinPreparar({super.key, required this.provider});

  final PreparacionCatalogoProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.estado != EstadoPreparacion.pospuesta) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.aviso.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.aviso.withValues(alpha: 0.45),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: AppColors.aviso,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Falta preparar tu catálogo',
                          style: TextStyle(
                            color: AppColors.aviso,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mientras tanto solo verás los productos más '
                          'recientes y no podrás buscar por nombre.',
                          style: TextStyle(
                            color: AppColors.aviso,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.azulTexto,
                side: const BorderSide(color: AppColors.hint),
              ),
              onPressed: provider.preparar,
              child: const Text('Preparar ahora'),
            ),
          ],
        );
      },
    );
  }
}
