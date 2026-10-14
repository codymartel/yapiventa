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
                  Divider(color: AppColors.bordeSutil, height: 1),
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
    final habilitado = estaHabilitado(destino);
    return Semantics(
      button: true,
      selected: activo,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: activo
              ? AppColors.blue.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onSeleccionar(destino),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
              child: Row(
                children: [
                  // El indicador de la izquierda solo aparece en el ítem
                  // activo: reinforces la posición sin ensuciar la lista.
                  if (activo)
                    Container(
                      width: 3,
                      height: 16,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: AppColors.blueLt,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    const SizedBox(width: 10),
                  Icon(
                    icono,
                    size: 18,
                    color: !habilitado
                        ? AppColors.dim
                        : (activo ? AppColors.blueLt : AppColors.muted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: !habilitado
                            ? AppColors.dim
                            : (activo ? AppColors.texto : AppColors.muted),
                        fontSize: 13,
                        fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!habilitado)
                    // Candado discreto: informa el bloqueo sin competir con
                    // la etiqueta ni con el ítem activo.
                    const Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: AppColors.dim,
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
