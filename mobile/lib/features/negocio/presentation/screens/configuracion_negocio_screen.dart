import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/configuracion_negocio_flow.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfiguracionNegocioScreen
// ═════════════════════════════════════════════════════════════════════════
// Wrapper de ruta del wizard de 4 pasos (migración de
// ConfiguracionNegocioScreen.kt). Conserva únicamente el andamiaje de
// navegación (Scaffold + SafeArea); la coordinación del guardado, la
// recarga de progreso, el bloqueo durante la operación, los errores, el
// PopScope y los callbacks viven en ConfiguracionNegocioFlow.
//
// IMPORTANTE: esta pantalla espera que YA exista un
// ConfiguracionNegocioProvider más arriba en el árbol de widgets — se
// crea en main.dart, envolviendo esta pantalla con ChangeNotifierProvider
// (ver onGenerateRoute de la ruta '/configurar-negocio').
// ═════════════════════════════════════════════════════════════════════════

class ConfiguracionNegocioScreen extends StatelessWidget {
  final String uid;
  final String? negocioId;
  final VoidCallback onVolver;
  final VoidCallback onCompletado;
  final Future<void> Function(
    String uid,
    String? negocioId,
  )? onRecargarProgreso;

  const ConfiguracionNegocioScreen({
    super.key,
    required this.uid,
    this.negocioId,
    required this.onVolver,
    required this.onCompletado,
    this.onRecargarProgreso,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: ConfiguracionNegocioFlow(
          uid: uid,
          negocioId: negocioId,
          onVolver: onVolver,
          onCompletado: onCompletado,
          onRecargarProgreso: onRecargarProgreso,
        ),
      ),
    );
  }
}