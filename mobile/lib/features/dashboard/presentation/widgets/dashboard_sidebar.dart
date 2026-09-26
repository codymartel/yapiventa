import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/authenticated_shell.dart';

enum DashboardDestination {
  inicio,
  productos,
  plantilla,
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
  final bool Function(DashboardDestination destino) estaHabilitado;

  const DashboardSidebar({
    super.key,
    required this.destinoActivo,
    required this.onSeleccionar,
    required this.estaHabilitado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AuthenticatedShell.navigationWidth,
      color: AppColors.superficie,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MarcaYapiVenta(),
            const SizedBox(height: 16),
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
                    destino: DashboardDestination.plantilla,
                    icono: Icons.palette_outlined,
                    texto: 'Plantilla web',
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
                  const SizedBox(height: 20),
                  Divider(color: AppColors.border),
                  const SizedBox(height: 6),
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
    final habilitado = estaHabilitado(destino);
    return Semantics(
      button: true,
      selected: activo,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Material(
          color: activo
              ? AppColors.blue.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: () => onSeleccionar(destino),
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    icono,
                    size: 20,
                    color: activo ? AppColors.blueLt : AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activo ? AppColors.texto : AppColors.muted,
                        fontSize: 13,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!habilitado)
                    const Icon(
                      Icons.lock_outline,
                      size: 15,
                      color: AppColors.muted,
                    )
                  else if (activo)
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YapiVenta',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'Panel de negocio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
