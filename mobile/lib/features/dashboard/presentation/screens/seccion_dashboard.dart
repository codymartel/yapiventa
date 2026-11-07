import '../widgets/dashboard_sidebar.dart';

/// La sección que el tablero tiene abierta. Una sola variable evita que haya
/// dos abiertas a la vez. Cada una sabe qué ayuda mostrar y qué ítem del menú
/// marcar como activo.
enum SeccionDashboard {
  inicio('inicio', DashboardDestination.inicio),
  rubro('rubro', DashboardDestination.inicio),
  configuracion('configuracion', DashboardDestination.configuracion),
  productos('productos', DashboardDestination.productos),
  plantilla('plantilla', DashboardDestination.plantilla),
  pedidos('pedidos', DashboardDestination.pedidos);

  const SeccionDashboard(this.ayudaId, this.destinoActivo);

  final String ayudaId;
  final DashboardDestination destinoActivo;
}
