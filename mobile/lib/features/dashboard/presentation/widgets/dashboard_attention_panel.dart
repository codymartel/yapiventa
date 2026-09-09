import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/dashboard_ui_state.dart';

class DashboardAttentionPanel extends StatelessWidget {
  final List<DashboardAttentionItem> items;
  final List<DashboardFeaturedProduct> productos;

  const DashboardAttentionPanel({
    super.key,
    required this.items,
    required this.productos,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Panel(
          titulo: 'Necesita tu atención',
          subtitulo: 'Prioridades para hoy',
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _AttentionRow(item: items[i]),
                if (i != items.length - 1)
                  Divider(height: 22, color: AppColors.border),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          titulo: 'Productos destacados',
          subtitulo: 'Movimiento del período',
          child: Column(
            children: [
              for (var i = 0; i < productos.length; i++) ...[
                _ProductRow(producto: productos[i]),
                if (i != productos.length - 1)
                  Divider(height: 22, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget child;

  const _Panel({
    required this.titulo,
    required this.subtitulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitulo,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final DashboardAttentionItem item;

  const _AttentionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final visual = switch (item.tipo) {
      DashboardAttentionType.stock => (
        Icons.inventory_2_outlined,
        const Color(0xFFFF895D),
      ),
      DashboardAttentionType.inventario => (
        Icons.event_busy_outlined,
        const Color(0xFFFFB557),
      ),
      DashboardAttentionType.reclamo => (
        Icons.forum_outlined,
        const Color(0xFFFF718B),
      ),
    };

    return Row(
      children: [
        _IconBox(icono: visual.$1, color: visual.$2),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.detalle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          item.valor,
          style: TextStyle(
            color: visual.$2,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  final DashboardFeaturedProduct producto;

  const _ProductRow({required this.producto});

  @override
  Widget build(BuildContext context) {
    final color = producto.stockBajo
        ? const Color(0xFFFF895D)
        : const Color(0xFF4E8BFF);
    return Row(
      children: [
        _IconBox(icono: Icons.shopping_bag_outlined, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                producto.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${producto.categoria} · ${producto.unidades} unidades',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          'S/ ${producto.ventas.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icono;
  final Color color;

  const _IconBox({required this.icono, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icono, color: color, size: 18),
    );
  }
}
