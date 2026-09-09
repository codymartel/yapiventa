import 'package:flutter/foundation.dart';
import '../state/dashboard_ui_state.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({DashboardUiState? initialState})
    : _state = initialState ?? _crearEstadoDemo(DashboardPeriod.semana);

  DashboardUiState _state;

  DashboardUiState get state => _state;

  void seleccionarPeriodo(DashboardPeriod periodo) {
    if (_state.periodo == periodo) return;
    _state = _crearEstadoDemo(periodo);
    notifyListeners();
  }
}

DashboardUiState _crearEstadoDemo(DashboardPeriod periodo) {
  final multiplicador = switch (periodo) {
    DashboardPeriod.hoy => 0.18,
    DashboardPeriod.semana => 1.0,
    DashboardPeriod.mes => 4.3,
  };

  return DashboardUiState(
    periodo: periodo,
    datosDemo: true,
    nombreNegocio: 'Bodega Central',
    ventasOnline: 2840 * multiplicador,
    ventasFisicas: 1935 * multiplicador,
    pedidosPendientes: periodo == DashboardPeriod.hoy ? 4 : 12,
    productosActivos: 86,
    quejasPendientes: 3,
    productosStockBajo: 7,
    ventasUltimos7Dias: const [
      DashboardSalesPoint(label: 'Lun', online: 340, fisicas: 220),
      DashboardSalesPoint(label: 'Mar', online: 420, fisicas: 280),
      DashboardSalesPoint(label: 'Mié', online: 365, fisicas: 245),
      DashboardSalesPoint(label: 'Jue', online: 510, fisicas: 310),
      DashboardSalesPoint(label: 'Vie', online: 590, fisicas: 390),
      DashboardSalesPoint(label: 'Sáb', online: 385, fisicas: 300),
      DashboardSalesPoint(label: 'Dom', online: 230, fisicas: 190),
    ],
    pedidosRecientes: const [
      DashboardRecentOrder(
        id: '#1048',
        cliente: 'María Torres',
        hora: 'Hace 8 min',
        total: 86.50,
        productos: 4,
        estado: DashboardOrderStatus.pendiente,
      ),
      DashboardRecentOrder(
        id: '#1047',
        cliente: 'Carlos Mendoza',
        hora: 'Hace 22 min',
        total: 42.90,
        productos: 2,
        estado: DashboardOrderStatus.preparando,
      ),
      DashboardRecentOrder(
        id: '#1046',
        cliente: 'Rosa Vargas',
        hora: 'Hace 41 min',
        total: 128.00,
        productos: 6,
        estado: DashboardOrderStatus.listo,
      ),
      DashboardRecentOrder(
        id: '#1045',
        cliente: 'Luis Ramírez',
        hora: 'Hace 1 h',
        total: 31.50,
        productos: 3,
        estado: DashboardOrderStatus.listo,
      ),
    ],
    necesitanAtencion: const [
      DashboardAttentionItem(
        titulo: 'Aceite vegetal 1 L',
        detalle: 'Stock por debajo del mínimo',
        valor: '2 unidades',
        tipo: DashboardAttentionType.stock,
      ),
      DashboardAttentionItem(
        titulo: 'Yogurt natural',
        detalle: 'Revisar fecha de vencimiento',
        valor: 'Vence pronto',
        tipo: DashboardAttentionType.inventario,
      ),
      DashboardAttentionItem(
        titulo: 'Pedido #1041',
        detalle: 'Cliente espera una respuesta',
        valor: '1 reclamo',
        tipo: DashboardAttentionType.reclamo,
      ),
    ],
    productosDestacados: const [
      DashboardFeaturedProduct(
        nombre: 'Arroz extra 5 kg',
        categoria: 'Abarrotes',
        unidades: 28,
        ventas: 532,
      ),
      DashboardFeaturedProduct(
        nombre: 'Leche entera',
        categoria: 'Lácteos',
        unidades: 21,
        ventas: 147,
      ),
      DashboardFeaturedProduct(
        nombre: 'Aceite vegetal 1 L',
        categoria: 'Abarrotes',
        unidades: 2,
        ventas: 126,
        stockBajo: true,
      ),
    ],
  );
}
