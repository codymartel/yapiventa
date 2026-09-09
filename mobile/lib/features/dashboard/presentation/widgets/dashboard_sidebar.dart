import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum DashboardDestination {
  inicio,
  productos,
  pedidos,
  ventas,
  quejas,
  configuracion,
  plan,
  ayuda,
}

class DashboardSidebar extends StatelessWidget {
  final DashboardDestination destinoActivo;
  final ValueChanged<DashboardDestination> onSeleccionar;

  const DashboardSidebar({
    super.key,
    required this.destinoActivo,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      color: AppColors.superficie,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MarcaYapiVenta(),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(
                    destino: DashboardDestination.inicio,
                    icono: Icons.space_dashboard_rounded,
                    texto: 'Inicio',
                  ),
                  _item(
                    destino: DashboardDestination.productos,
                    icono: Icons.inventory_2_outlined,
                    texto: 'Productos',
                  ),
                  _item(
                    destino: DashboardDestination.pedidos,
                    icono: Icons.receipt_long_outlined,
                    texto: 'Pedidos',
                  ),
                  _item(
                    destino: DashboardDestination.ventas,
                    icono: Icons.point_of_sale_outlined,
                    texto: 'Ventas',
                  ),
                  _item(
                    destino: DashboardDestination.quejas,
                    icono: Icons.forum_outlined,
                    texto: 'Reclamaciones',
                  ),
                  _item(
                    destino: DashboardDestination.configuracion,
                    icono: Icons.tune_rounded,
                    texto: 'Configuración',
                  ),
                  const SizedBox(height: 28),
                  Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  _item(
                    destino: DashboardDestination.plan,
                    icono: Icons.workspace_premium_outlined,
                    texto: 'Plan',
                  ),
                  _item(
                    destino: DashboardDestination.ayuda,
                    icono: Icons.help_outline_rounded,
                    texto: 'Ayuda',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item({
    required DashboardDestination destino,
    required IconData icono,
    required String texto,
  }) {
    final activo = destino == destinoActivo;
    return Semantics(
      button: true,
      selected: activo,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          color: activo
              ? AppColors.blue.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onSeleccionar(destino),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    icono,
                    size: 21,
                    color: activo ? AppColors.blueLt : AppColors.muted,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      texto,
                      style: TextStyle(
                        color: activo ? AppColors.texto : AppColors.muted,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (activo)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.blueLt,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarcaYapiVenta extends StatelessWidget {
  const _MarcaYapiVenta();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.blueLt, AppColors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YapiVenta',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Panel de negocio',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
