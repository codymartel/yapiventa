import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/dashboard_ui_state.dart';

class DashboardSummaryCards extends StatelessWidget {
  final DashboardUiState state;

  const DashboardSummaryCards({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      _ResumenDato(
        titulo: 'Ventas online',
        valor: _moneda(state.ventasOnline),
        detalle: 'Canal digital',
        icono: Icons.language_rounded,
        color: const Color(0xFF4E8BFF),
      ),
      _ResumenDato(
        titulo: 'Ventas físicas',
        valor: _moneda(state.ventasFisicas),
        detalle: 'Punto de venta',
        icono: Icons.storefront_outlined,
        color: const Color(0xFF35C59A),
      ),
      _ResumenDato(
        titulo: 'Pedidos pendientes',
        valor: state.pedidosPendientes.toString(),
        detalle: 'Requieren seguimiento',
        icono: Icons.receipt_long_outlined,
        color: const Color(0xFFFFB557),
      ),
      _ResumenDato(
        titulo: 'Productos activos',
        valor: state.productosActivos.toString(),
        detalle: 'Visibles en catálogo',
        icono: Icons.inventory_2_outlined,
        color: const Color(0xFF8D7CFF),
      ),
      _ResumenDato(
        titulo: 'Reclamaciones',
        valor: state.quejasPendientes.toString(),
        detalle: 'Pendientes de respuesta',
        icono: Icons.forum_outlined,
        color: const Color(0xFFFF718B),
      ),
      _ResumenDato(
        titulo: 'Stock bajo',
        valor: state.productosStockBajo.toString(),
        detalle: 'Productos por reponer',
        icono: Icons.warning_amber_rounded,
        color: const Color(0xFFFF895D),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        const espacio = 14.0;
        final ancho =
            (constraints.maxWidth - (espacio * (columnas - 1))) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final tarjeta in tarjetas)
              SizedBox(
                width: ancho,
                child: _ResumenCard(dato: tarjeta),
              ),
          ],
        );
      },
    );
  }
}

String _moneda(double valor) => 'S/ ${valor.toStringAsFixed(2)}';

class _ResumenDato {
  final String titulo;
  final String valor;
  final String detalle;
  final IconData icono;
  final Color color;

  const _ResumenDato({
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.icono,
    required this.color,
  });
}

class _ResumenCard extends StatelessWidget {
  final _ResumenDato dato;

  const _ResumenCard({required this.dato});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dato.titulo,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  dato.valor,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dato.detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.texto.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: dato.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(dato.icono, color: dato.color, size: 21),
          ),
        ],
      ),
    );
  }
}
