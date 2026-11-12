import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// «Plan» del menú. Por pedido del usuario: avisa que habrá planes y cuenta
/// lo que ya se puede usar hoy, **sin prometer nada** del futuro (ni precios
/// ni funciones). Solo texto: 0 lecturas, sin cobros.
class PlanesScreen extends StatelessWidget {
  const PlanesScreen({super.key});

  /// Lo que la app hace hoy. Si se agrega o se quita una sección del menú,
  /// actualizar esta lista.
  static const loQueTienesHoy = <(IconData, String, String)>[
    (
      Icons.inventory_2_outlined,
      'Productos',
      'Sencillos, por peso, con modelos, con extras y combos, con foto y '
          'stock.',
    ),
    (
      Icons.palette_outlined,
      'Tienda web',
      'Tu página con tus productos y una plantilla a elegir, para compartir '
          'por WhatsApp.',
    ),
    (
      Icons.receipt_long_outlined,
      'Pedidos',
      'Confirma, entrega, cobra o cancela los pedidos de tu tienda.',
    ),
    (
      Icons.point_of_sale_outlined,
      'Ventas',
      'Cobra en tu local, anota tus gastos y mira cómo va tu día.',
    ),
    (
      Icons.storefront_outlined,
      'Negocio',
      'Tus datos, formas de pago, zonas de delivery y horarios.',
    ),
    (
      Icons.settings_outlined,
      'Configuración',
      'El tamaño de la letra de la app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Pronto tendremos planes',
              style: AppTypography.screenTitle.copyWith(color: AppColors.texto),
            ),
            const SizedBox(height: 4),
            Text(
              'Mientras tanto, disfruta del acceso a todo nuestro catálogo.',
              style: AppTypography.screenSubtitle.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Esto es lo que ya puedes usar',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: AppFontSize.subtitulo,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final (icono, titulo, detalle) in loQueTienesHoy)
              _FilaHoy(icono: icono, titulo: titulo, detalle: detalle),
          ],
        ),
      ),
    );
  }
}

class _FilaHoy extends StatelessWidget {
  const _FilaHoy({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bordeSutil)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: AppColors.azulTexto),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: AppFontSize.cuerpo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: AppFontSize.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
