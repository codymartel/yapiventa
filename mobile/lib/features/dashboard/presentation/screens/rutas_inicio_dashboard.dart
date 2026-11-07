import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/domain/politica_acceso.dart';
import '../../../auth/presentation/providers/acceso_provider.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../../../negocio/presentation/providers/configuracion_negocio_provider.dart';
import '../../../negocio/presentation/widgets/configuracion_negocio_flow.dart';
import '../../../negocio/presentation/widgets/seleccion_negocio_flow.dart';
import 'dashboard_contenido_inicio.dart';

/// Las pantallas del navegador interno del tablero: la portada de Inicio,
/// Rubro y Configuración. No guarda estado: lo pide al tablero con funciones.
class RutasInicioDashboard {
  final String uid;
  final String? negocioId;
  final ValueListenable<ProgresoConfiguracion> progreso;
  final String Function() rubroActual;
  final ConfiguracionNegocioProvider? Function() providerConfiguracion;
  final bool Function() vieneDeProducto;
  final VoidCallback alVolverAlProducto;
  final Future<void> Function()? recargarProgreso;
  final ValueChanged<String> alCambiarRubro;
  final void Function(
    BuildContext contexto,
    ProgresoConfiguracion progreso,
    EtapaConfiguracion etapa,
  )
  alAbrirEtapa;

  const RutasInicioDashboard({
    required this.uid,
    required this.negocioId,
    required this.progreso,
    required this.rubroActual,
    required this.providerConfiguracion,
    required this.vieneDeProducto,
    required this.alVolverAlProducto,
    required this.recargarProgreso,
    required this.alCambiarRubro,
    required this.alAbrirEtapa,
  });

  Route<dynamic> crear(RouteSettings settings) {
    if (settings.name == RutasAcceso.rubro) return _rubro(settings);
    if (settings.name == RutasAcceso.negocio &&
        providerConfiguracion() != null) {
      return _configuracion(settings);
    }
    return crearInicio(settings);
  }

  Route<dynamic> crearInicio(RouteSettings settings) {
    return MaterialPageRoute<Object?>(
      settings: settings,
      builder: (contexto) => ValueListenableBuilder<ProgresoConfiguracion>(
        valueListenable: progreso,
        builder: (contexto, progreso, _) => DashboardContenidoInicio(
          progreso: progreso,
          onAbrirEtapa: (etapa) => alAbrirEtapa(contexto, progreso, etapa),
        ),
      ),
    );
  }

  Route<dynamic> _configuracion(RouteSettings settings) {
    final provider = providerConfiguracion()!;
    return MaterialPageRoute<Object?>(
      settings: settings,
      builder: (contexto) =>
          ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
            value: provider,
            child: ConfiguracionNegocioFlow(
              uid: uid,
              negocioId: negocioId,
              onVolver: () => _regresar(contexto),
              onCompletado: () => _regresar(contexto),
              onVolverAlProducto: vieneDeProducto() ? alVolverAlProducto : null,
              onRecargarProgreso: recargarProgreso == null
                  ? null
                  : (uid, negocioId) => recargarProgreso!(),
            ),
          ),
    );
  }

  Route<dynamic> _rubro(RouteSettings settings) {
    return MaterialPageRoute<Object?>(
      settings: settings,
      builder: (contexto) => SeleccionNegocioFlow(
        rubroInicial: rubroActual(),
        onTipoSeleccionado: (rubro) async =>
            contexto.read<AccesoProvider>().guardarRubro(rubro),
        onRubroCambiado: alCambiarRubro,
        onVolver: () => _regresar(contexto),
        onCompletado: () => _regresar(contexto),
      ),
    );
  }

  void _regresar(BuildContext contexto) {
    final navegador = Navigator.of(contexto);
    if (navegador.canPop()) navegador.pop();
  }
}
