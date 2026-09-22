import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/configuracion_negocio_provider.dart';
import '../widgets/configuracion_negocio_content.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfiguracionNegocioScreen
// ═════════════════════════════════════════════════════════════════════════
// Marco raíz del wizard de 4 pasos, migración de
// ConfiguracionNegocioScreen.kt. Conserva el andamiaje de navegación
// (Scaffold + SafeArea + PopScope) y delega el contenido del wizard a
// ConfiguracionNegocioContent.
//
// IMPORTANTE: esta pantalla espera que YA exista un
// ConfiguracionNegocioProvider más arriba en el árbol de widgets — se
// crea en main.dart, envolviendo esta pantalla con ChangeNotifierProvider
// (ver onGenerateRoute de la ruta '/configurar-negocio').
// ═════════════════════════════════════════════════════════════════════════

class ConfiguracionNegocioScreen extends StatelessWidget {
  final String uid;
  final String rubro;
  final VoidCallback onVolver;
  final VoidCallback onFinalizar;

  const ConfiguracionNegocioScreen({
    super.key,
    required this.uid,
    required this.rubro,
    required this.onVolver,
    required this.onFinalizar,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return PopScope(
      canPop: !p.guardando,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        body: AbsorbPointer(
          absorbing: p.guardando,
          child: SafeArea(
            child: ConfiguracionNegocioContent(
              rubro: rubro,
              onVolver: onVolver,
              onFinalizar: () async {
                final exito = await p.guardar(uid);
                if (exito && context.mounted) onFinalizar();
              },
            ),
          ),
        ),
      ),
    );
  }
}
