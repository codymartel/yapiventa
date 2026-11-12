import '../../../auth/domain/politica_acceso.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../../../negocio/presentation/widgets/seleccion_negocio_content.dart';
import '../state/dashboard_ui_state.dart';
import '../widgets/dashboard_sidebar.dart';

/// La sección que el tablero tiene abierta. Una sola variable evita que haya
/// dos abiertas a la vez. Cada una sabe qué ayuda mostrar y qué ítem del menú
/// marcar como activo.
enum SeccionDashboard {
  inicio('inicio', DashboardDestination.inicio),
  rubro('rubro', DashboardDestination.inicio),
  // Conserva la clave de ayuda vieja: quien ya vio la ayuda de la antigua
  // «Configuración» no la vuelve a ver abrirse sola.
  negocio('configuracion', DashboardDestination.negocio),
  productos('productos', DashboardDestination.productos),
  plantilla('plantilla', DashboardDestination.plantilla),
  pedidos('pedidos', DashboardDestination.pedidos),
  caja('caja', DashboardDestination.ventas),
  apariencia('apariencia', DashboardDestination.configuracion),
  plan('plan', DashboardDestination.plan);

  const SeccionDashboard(this.ayudaId, this.destinoActivo);

  final String ayudaId;
  final DashboardDestination destinoActivo;
}

/// Si un ítem del menú se puede abrir: Inicio, Configuración (apariencia) y
/// Plan siempre; Productos, Plantilla y Negocio según la etapa de
/// configuración; el resto (Pedidos, Ventas…) solo con la configuración
/// completa.
bool destinoHabilitado(
  DashboardDestination destino,
  ProgresoConfiguracion progreso,
) {
  return switch (destino) {
    DashboardDestination.inicio ||
    DashboardDestination.configuracion ||
    DashboardDestination.plan => true,
    DashboardDestination.productos => PoliticaAcceso.permite(
      RutasAcceso.productos,
      progreso,
    ),
    DashboardDestination.plantilla => PoliticaAcceso.permite(
      RutasAcceso.plantilla,
      progreso,
    ),
    DashboardDestination.negocio => PoliticaAcceso.permite(
      RutasAcceso.negocio,
      progreso,
    ),
    _ => progreso.completo,
  };
}

/// El rubro que la ayuda sabe mostrar: uno no disponible se trata como Otros.
String rubroCompatibleDashboard(String rubro) {
  if (rubro == 'Farmacia' || rubro == 'Ferretería') return 'Otros';
  return SeleccionNegocioContent.esRubroDisponible(rubro) ? rubro : 'Otros';
}

/// El nombre del negocio para la barra de arriba: el de su configuración o,
/// si falta, el del tablero.
String nombreNegocioDashboard(
  ProgresoConfiguracion progreso,
  DashboardUiState state,
) {
  final nombre = progreso.catalogo.configuracionInicial['nombreNegocio'];
  return nombre is String && nombre.trim().isNotEmpty
      ? nombre.trim()
      : state.nombreNegocio;
}
