import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../providers/dashboard_provider.dart';
import '../state/dashboard_ui_state.dart';
import 'dashboard_quick_actions.dart';
import 'dashboard_recent_orders.dart';
import 'dashboard_sales_chart.dart';
import 'dashboard_setup_panel.dart';
import 'dashboard_summary_cards.dart';

class DashboardHomeContent extends StatelessWidget {
  final DashboardUiState state;
  final ProgresoConfiguracion progreso;
  final ValueChanged<EtapaConfiguracion> onAbrirEtapa;
  final VoidCallback onAgregarProducto;
  final VoidCallback onActualizarStock;
  final VoidCallback onVerPedidos;
  final VoidCallback onResponderQueja;

  const DashboardHomeContent({
    super.key,
    required this.state,
    required this.progreso,
    required this.onAbrirEtapa,
    required this.onAgregarProducto,
    required this.onActualizarStock,
    required this.onVerPedidos,
    required this.onResponderQueja,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: MediaQuery.sizeOf(context).width < 600
          ? const EdgeInsets.fromLTRB(16, 16, 16, 28)
          : const EdgeInsets.fromLTRB(26, 28, 26, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardSetupPanel(
                progreso: progreso,
                onAbrirEtapa: onAbrirEtapa,
              ),
              if (!progreso.completo) const SizedBox(height: 18),
              _DashboardHeading(periodo: state.periodo),
              const SizedBox(height: 24),
              DashboardSummaryCards(state: state),
              const SizedBox(height: 18),
              DashboardSalesChart(puntos: state.ventasUltimos7Dias),
              const SizedBox(height: 18),
              DashboardQuickActions(
                onAgregarProducto: onAgregarProducto,
                onActualizarStock: onActualizarStock,
                onVerPedidos: onVerPedidos,
                onResponderQueja: onResponderQueja,
              ),
              const SizedBox(height: 18),
              DashboardRecentOrders(
                pedidos: state.pedidosRecientes,
                onVerTodos: onVerPedidos,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeading extends StatelessWidget {
  final DashboardPeriod periodo;

  const _DashboardHeading({required this.periodo});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de tu negocio',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Resumen de ${periodo.label.toLowerCase()} · '
              'gráfico con referencia de los últimos 7 días.',
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
        _PeriodSelector(periodo: periodo),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final DashboardPeriod periodo;

  const _PeriodSelector({required this.periodo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opcion in DashboardPeriod.values)
            Semantics(
              selected: opcion == periodo,
              button: true,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: TextButton(
                  onPressed: () => context
                      .read<DashboardProvider>()
                      .seleccionarPeriodo(opcion),
                  style: TextButton.styleFrom(
                    foregroundColor: opcion == periodo
                        ? AppColors.texto
                        : AppColors.muted,
                    backgroundColor: opcion == periodo
                        ? AppColors.blue
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(opcion.label),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
