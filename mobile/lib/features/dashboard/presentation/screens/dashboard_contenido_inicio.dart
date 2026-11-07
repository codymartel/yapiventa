import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/domain/politica_acceso.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_home_content.dart';

/// Avisa cuando se cierra la ruta interna de Rubro o de Configuración.
class ObservadorRutasInternas extends NavigatorObserver {
  final VoidCallback _alRegresar;

  ObservadorRutasInternas(this._alRegresar);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final nombre = route.settings.name;
    if (nombre != RutasAcceso.rubro && nombre != RutasAcceso.negocio) return;
    _alRegresar();
  }
}

/// Un aviso corto abajo, que reemplaza al anterior.
void mostrarAvisoDashboard(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// El contenido de la pantalla de Inicio del tablero.
class DashboardContenidoInicio extends StatelessWidget {
  final ProgresoConfiguracion progreso;
  final ValueChanged<EtapaConfiguracion> onAbrirEtapa;

  const DashboardContenidoInicio({
    super.key,
    required this.progreso,
    required this.onAbrirEtapa,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardProvider>().state;
    return DashboardHomeContent(
      state: state,
      progreso: progreso,
      onAbrirEtapa: onAbrirEtapa,
      onAgregarProducto: () => progreso.negocioCompleto
          ? onAbrirEtapa(EtapaConfiguracion.productos)
          : mostrarAvisoDashboard(
              context,
              'Completa primero las etapas pendientes de configuración.',
            ),
    );
  }
}
