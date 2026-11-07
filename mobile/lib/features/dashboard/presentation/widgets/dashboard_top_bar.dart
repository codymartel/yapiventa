import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/authenticated_shell.dart';
import '../../../../core/widgets/enlaces_legales.dart';

class DashboardTopBar extends StatelessWidget {
  final String nombreNegocio;
  final VoidCallback onElegirPlantilla;
  final VoidCallback onVerTienda;
  final VoidCallback? onAbrirMenu;
  final VoidCallback? onAbrirAyuda;
  final String email;
  final VoidCallback onCerrarSesion;
  final VoidCallback? onEliminarCuenta;

  const DashboardTopBar({
    super.key,
    required this.nombreNegocio,
    required this.onElegirPlantilla,
    required this.onVerTienda,
    this.onAbrirMenu,
    this.onAbrirAyuda,
    required this.email,
    required this.onCerrarSesion,
    this.onEliminarCuenta,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 700;
        final separacion = compacto ? 2.0 : 10.0;
        return Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.symmetric(
            horizontal: compacto ? 10 : 20,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.fondo.withValues(alpha: 0.94),
            border: Border(bottom: BorderSide(color: AppColors.bordeSutil)),
          ),
          child: Row(
            children: [
              if (onAbrirMenu != null) ...[
                IconButton(
                  onPressed: onAbrirMenu,
                  tooltip: 'Abrir menú',
                  color: AppColors.texto,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.menu_rounded),
                ),
                SizedBox(width: separacion),
              ],
              // La marca ya vive en el sidebar: aquí solo el negocio, de
              // forma discreta, porque el título de la pantalla va debajo.
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        nombreNegocio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.topBarBusiness.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: separacion),
              if (onAbrirAyuda != null) ...[
                IconButton(
                  key: AuthenticatedShell.helpButtonKey,
                  onPressed: onAbrirAyuda,
                  tooltip: 'Ayuda',
                  icon: const Text('ⓘ', style: TextStyle(fontSize: 20)),
                ),
                SizedBox(width: separacion),
              ],
              IconButton(
                onPressed: onElegirPlantilla,
                tooltip: 'Elegir plantilla',
                color: AppColors.blueLt,
                icon: const Icon(Icons.palette_outlined),
              ),
              SizedBox(width: separacion),
              PopupMenuButton<String>(
                tooltip: 'Cuenta',
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (value) {
                  if (value == 'privacidad') {
                    abrirEnlaceLegal(UrlsLegales.privacidad);
                  }
                  if (value == 'terminos') {
                    abrirEnlaceLegal(UrlsLegales.terminos);
                  }
                  if (value == 'logout') onCerrarSesion();
                  if (value == 'eliminar') onEliminarCuenta?.call();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text(email.isEmpty ? 'Mi cuenta' : email),
                  ),
                  const PopupMenuItem<String>(
                    value: 'privacidad',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.privacy_tip_outlined),
                      title: Text('Política de privacidad'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'terminos',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.description_outlined),
                      title: Text('Términos de uso'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout),
                      title: Text('Cerrar sesión'),
                    ),
                  ),
                  if (onEliminarCuenta != null)
                    const PopupMenuItem<String>(
                      value: 'eliminar',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.error,
                        ),
                        title: Text(
                          'Eliminar mi cuenta',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: separacion),
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
                      horizontal: 14,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ver tienda web'),
                ),
            ],
          ),
        );
      },
    );
  }
}
