import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/dashboard_provider.dart';
import '../state/dashboard_ui_state.dart';
import '../widgets/dashboard_attention_panel.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_recent_orders.dart';
import '../widgets/dashboard_sales_chart.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_summary_cards.dart';
import '../widgets/dashboard_top_bar.dart';

class DashboardWebScreen extends StatelessWidget {
  const DashboardWebScreen({super.key});

  static const _desktopBreakpoint = 1050.0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardProvider>().state;

    return LayoutBuilder(
      builder: (context, constraints) {
        final esDesktop = constraints.maxWidth >= _desktopBreakpoint;
        return Scaffold(
          key: const Key('dashboard-web-screen'),
          backgroundColor: AppColors.fondo,
          drawer: esDesktop
              ? null
              : Drawer(
                  width: 252,
                  backgroundColor: AppColors.superficie,
                  child: DashboardSidebar(
                    destinoActivo: DashboardDestination.inicio,
                    onSeleccionar: (destino) {
                      Navigator.of(context).pop();
                      _seleccionarDestino(context, destino);
                    },
                  ),
                ),
          body: Row(
            children: [
              if (esDesktop)
                DashboardSidebar(
                  destinoActivo: DashboardDestination.inicio,
                  onSeleccionar: (destino) =>
                      _seleccionarDestino(context, destino),
                ),
              Expanded(
                child: Column(
                  children: [
                    Builder(
                      builder: (topBarContext) => DashboardTopBar(
                        nombreNegocio: state.nombreNegocio,
                        onVerTienda: () => _mostrarProximamente(
                          context,
                          'La tienda web se conectará cuando tengamos el slug real.',
                        ),
                        onAbrirMenu: esDesktop
                            ? null
                            : () => Scaffold.of(topBarContext).openDrawer(),
                      ),
                    ),
                    Expanded(
                      child: _DashboardContent(
                        state: state,
                        onAgregarProducto: () =>
                            Navigator.of(context).pushNamed('/productos'),
                        onActualizarStock: () => _mostrarProximamente(
                          context,
                          'El módulo de stock estará disponible próximamente.',
                        ),
                        onVerPedidos: () => _mostrarProximamente(
                          context,
                          'El módulo de pedidos estará disponible próximamente.',
                        ),
                        onResponderQueja: () => _mostrarProximamente(
                          context,
                          'El módulo de reclamaciones estará disponible próximamente.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _seleccionarDestino(BuildContext context, DashboardDestination destino) {
    switch (destino) {
      case DashboardDestination.inicio:
        return;
      case DashboardDestination.productos:
        Navigator.of(context).pushNamed('/productos');
        return;
      case DashboardDestination.pedidos:
        _mostrarProximamente(
          context,
          'Pedidos estará disponible próximamente.',
        );
        return;
      case DashboardDestination.ventas:
        _mostrarProximamente(context, 'Ventas estará disponible próximamente.');
        return;
      case DashboardDestination.quejas:
        _mostrarProximamente(
          context,
          'Reclamaciones estará disponible próximamente.',
        );
        return;
      case DashboardDestination.configuracion:
        _mostrarProximamente(
          context,
          'Configuración estará disponible al conectar los datos del negocio.',
        );
        return;
      case DashboardDestination.plan:
        _mostrarProximamente(context, 'Plan estará disponible próximamente.');
        return;
      case DashboardDestination.ayuda:
        _mostrarProximamente(context, 'Ayuda estará disponible próximamente.');
        return;
    }
  }

  void _mostrarProximamente(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardUiState state;
  final VoidCallback onAgregarProducto;
  final VoidCallback onActualizarStock;
  final VoidCallback onVerPedidos;
  final VoidCallback onResponderQueja;

  const _DashboardContent({
    required this.state,
    required this.onAgregarProducto,
    required this.onActualizarStock,
    required this.onVerPedidos,
    required this.onResponderQueja,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DashboardHeading(
                periodo: state.periodo,
                datosDemo: state.datosDemo,
              ),
              const SizedBox(height: 24),
              DashboardSummaryCards(state: state),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final dosColumnas = constraints.maxWidth >= 940;
                  if (!dosColumnas) {
                    return Column(
                      children: [
                        DashboardSalesChart(puntos: state.ventasUltimos7Dias),
                        const SizedBox(height: 16),
                        DashboardAttentionPanel(
                          items: state.necesitanAtencion,
                          productos: state.productosDestacados,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: DashboardSalesChart(
                          puntos: state.ventasUltimos7Dias,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: DashboardAttentionPanel(
                          items: state.necesitanAtencion,
                          productos: state.productosDestacados,
                        ),
                      ),
                    ],
                  );
                },
              ),
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
  final bool datosDemo;

  const _DashboardHeading({required this.periodo, required this.datosDemo});

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
            if (datosDemo) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'DATOS DE DEMOSTRACIÓN',
                  style: TextStyle(
                    color: AppColors.blueLt,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
