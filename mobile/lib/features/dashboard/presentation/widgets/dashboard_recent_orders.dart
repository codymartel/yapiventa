import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/dashboard_ui_state.dart';

class DashboardRecentOrders extends StatelessWidget {
  final List<DashboardRecentOrder> pedidos;
  final VoidCallback onVerTodos;

  const DashboardRecentOrders({
    super.key,
    required this.pedidos,
    required this.onVerTodos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedidos recientes',
                      style: TextStyle(
                        color: AppColors.texto,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Últimos movimientos de tu tienda',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onVerTodos, child: const Text('Ver todos')),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < pedidos.length; i++) ...[
            _PedidoRow(pedido: pedidos[i]),
            if (i != pedidos.length - 1)
              Divider(height: 22, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _PedidoRow extends StatelessWidget {
  final DashboardRecentOrder pedido;

  const _PedidoRow({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final color = switch (pedido.estado) {
      DashboardOrderStatus.pendiente => const Color(0xFFFFB557),
      DashboardOrderStatus.preparando => const Color(0xFF4E8BFF),
      DashboardOrderStatus.listo => const Color(0xFF35C59A),
    };
    final total = Text(
      'S/ ${pedido.total.toStringAsFixed(2)}',
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
    final estado = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pedido.estado.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 520;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.superficie,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                pedido.id.replaceFirst('#', ''),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pedido.cliente,
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
                    '${pedido.hora} · ${pedido.productos} productos',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  if (compacto) ...[
                    const SizedBox(height: 9),
                    Wrap(spacing: 12, runSpacing: 6, children: [total, estado]),
                  ],
                ],
              ),
            ),
            if (!compacto) ...[
              const SizedBox(width: 12),
              total,
              const SizedBox(width: 14),
              estado,
            ],
          ],
        );
      },
    );
  }
}
