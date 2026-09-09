enum DashboardPeriod { hoy, semana, mes }

extension DashboardPeriodLabel on DashboardPeriod {
  String get label => switch (this) {
    DashboardPeriod.hoy => 'Hoy',
    DashboardPeriod.semana => 'Semana',
    DashboardPeriod.mes => 'Mes',
  };
}

enum DashboardOrderStatus { pendiente, preparando, listo }

extension DashboardOrderStatusLabel on DashboardOrderStatus {
  String get label => switch (this) {
    DashboardOrderStatus.pendiente => 'Pendiente',
    DashboardOrderStatus.preparando => 'Preparando',
    DashboardOrderStatus.listo => 'Listo',
  };
}

enum DashboardAttentionType { stock, inventario, reclamo }

class DashboardSalesPoint {
  final String label;
  final double online;
  final double fisicas;

  const DashboardSalesPoint({
    required this.label,
    required this.online,
    required this.fisicas,
  });
}

class DashboardRecentOrder {
  final String id;
  final String cliente;
  final String hora;
  final double total;
  final int productos;
  final DashboardOrderStatus estado;

  const DashboardRecentOrder({
    required this.id,
    required this.cliente,
    required this.hora,
    required this.total,
    required this.productos,
    required this.estado,
  });
}

class DashboardAttentionItem {
  final String titulo;
  final String detalle;
  final String valor;
  final DashboardAttentionType tipo;

  const DashboardAttentionItem({
    required this.titulo,
    required this.detalle,
    required this.valor,
    required this.tipo,
  });
}

class DashboardFeaturedProduct {
  final String nombre;
  final String categoria;
  final int unidades;
  final double ventas;
  final bool stockBajo;

  const DashboardFeaturedProduct({
    required this.nombre,
    required this.categoria,
    required this.unidades,
    required this.ventas,
    this.stockBajo = false,
  });
}

class DashboardUiState {
  final DashboardPeriod periodo;
  final bool datosDemo;
  final String nombreNegocio;
  final double ventasOnline;
  final double ventasFisicas;
  final int pedidosPendientes;
  final int productosActivos;
  final int quejasPendientes;
  final int productosStockBajo;
  final List<DashboardSalesPoint> ventasUltimos7Dias;
  final List<DashboardRecentOrder> pedidosRecientes;
  final List<DashboardAttentionItem> necesitanAtencion;
  final List<DashboardFeaturedProduct> productosDestacados;

  DashboardUiState({
    required this.periodo,
    required this.datosDemo,
    required this.nombreNegocio,
    required this.ventasOnline,
    required this.ventasFisicas,
    required this.pedidosPendientes,
    required this.productosActivos,
    required this.quejasPendientes,
    required this.productosStockBajo,
    required List<DashboardSalesPoint> ventasUltimos7Dias,
    required List<DashboardRecentOrder> pedidosRecientes,
    required List<DashboardAttentionItem> necesitanAtencion,
    required List<DashboardFeaturedProduct> productosDestacados,
  }) : ventasUltimos7Dias = List.unmodifiable(ventasUltimos7Dias),
       pedidosRecientes = List.unmodifiable(pedidosRecientes),
       necesitanAtencion = List.unmodifiable(necesitanAtencion),
       productosDestacados = List.unmodifiable(productosDestacados);
}
