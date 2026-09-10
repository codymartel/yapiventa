import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardTopBar extends StatelessWidget {
  final String nombreNegocio;
  final VoidCallback onElegirPlantilla;
  final VoidCallback onVerTienda;
  final VoidCallback? onAbrirMenu;
  final String email;
  final VoidCallback onCerrarSesion;

  const DashboardTopBar({
    super.key,
    required this.nombreNegocio,
    required this.onElegirPlantilla,
    required this.onVerTienda,
    this.onAbrirMenu,
    required this.email,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).width < 700;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.fondo.withValues(alpha: 0.94),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onAbrirMenu != null) ...[
            IconButton(
              onPressed: onAbrirMenu,
              tooltip: 'Abrir menú',
              color: AppColors.texto,
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YapiVenta',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  nombreNegocio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onElegirPlantilla,
            tooltip: 'Elegir plantilla',
            color: AppColors.blueLt,
            icon: const Icon(Icons.palette_outlined),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Cuenta',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'logout') onCerrarSesion();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(email.isEmpty ? 'Mi cuenta' : email),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          if (compacto)
            IconButton(
              onPressed: onVerTienda,
              tooltip: 'Ver tienda web',
              icon: const Icon(Icons.open_in_new_rounded),
            )
          else
            OutlinedButton.icon(
              onPressed: onVerTienda,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.texto,
                side: BorderSide(
                  color: AppColors.blueLt.withValues(alpha: 0.55),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Ver tienda web'),
            ),
        ],
      ),
    );
  }
}
