import 'package:flutter/foundation.dart';
import '../state/dashboard_ui_state.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({DashboardUiState? initialState})
    : _state = initialState ?? _estadoVacio(DashboardPeriod.semana);

  DashboardUiState _state;

  DashboardUiState get state => _state;

  void seleccionarPeriodo(DashboardPeriod periodo) {
    if (_state.periodo == periodo) return;
    _state = _estadoVacio(periodo);
    notifyListeners();
  }
}

DashboardUiState _estadoVacio(DashboardPeriod periodo) {
  return DashboardUiState(
    periodo: periodo,
    nombreNegocio: '',
    ventasOnline: 0,
    ventasFisicas: 0,
    pedidosPendientes: 0,
    productosActivos: 0,
    quejasPendientes: 0,
    productosStockBajo: 0,
    ventasUltimos7Dias: const [],
    pedidosRecientes: const [],
    necesitanAtencion: const [],
    productosDestacados: const [],
  );
}
