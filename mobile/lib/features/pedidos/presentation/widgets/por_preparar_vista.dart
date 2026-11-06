import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/por_preparar_pedidos.dart';

/// «Por preparar ahora»: lo que suman los pedidos nuevos y confirmados ya
/// cargados, un chip por producto. Texto plano (los nombres vienen del
/// catálogo del negocio).
class PorPrepararVista extends StatelessWidget {
  const PorPrepararVista({super.key, required this.items});

  final List<ItemPorPreparar> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bordeSutil),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POR PREPARAR AHORA · de los pedidos nuevos y confirmados cargados',
            style: TextStyle(
              color: AppColors.hint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'Nada por preparar.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.superficie,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.bordeSutil),
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: '${item.nombre} ',
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: item.cantidadTexto,
                            style: const TextStyle(
                              color: AppColors.azulTexto,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
