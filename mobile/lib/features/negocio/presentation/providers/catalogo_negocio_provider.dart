import 'package:flutter/foundation.dart';

import '../../application/use_cases/obtener_catalogo_negocio.dart';
import '../../application/use_cases/obtener_catalogo_venta.dart';
import '../../domain/models/catalogo_negocio.dart';
import '../../domain/models/catalogo_venta/catalogo_venta_persistido.dart';

class CatalogoNegocioProvider extends ChangeNotifier {
  final String uid;
  final ObtenerCatalogoNegocio _obtenerCatalogoNegocio;

  /// Catálogo maestro de venta (presentaciones y medidas). Es OPCIONAL a
  /// propósito: quien todavía no lo inyecta sigue funcionando igual, con
  /// [catalogoVenta] en null y [ventaCargada] en false. Cuando se inyecta,
  /// [cargar] lo dispara junto al catálogo legacy sin que falle la carga
  /// legacy si este falla.
  final ObtenerCatalogoVenta? _obtenerCatalogoVenta;

  CatalogoNegocioProvider({
    required this.uid,
    required ObtenerCatalogoNegocio obtenerCatalogoNegocio,
    ObtenerCatalogoVenta? obtenerCatalogoVenta,
    CatalogoNegocio? catalogoInicial,
  }) : _obtenerCatalogoNegocio = obtenerCatalogoNegocio,
       _obtenerCatalogoVenta = obtenerCatalogoVenta,
       _catalogo = catalogoInicial;

  CatalogoNegocio? _catalogo;
  Future<void>? _cargaEnCurso;
  bool _cargando = false;
  bool _disposed = false;
  String? _errorMessage;

  CatalogoVentaPersistido? _catalogoVenta;
  Future<void>? _cargaVentaEnCurso;
  bool _cargandoVenta = false;
  String? _ventaErrorMessage;

  CatalogoNegocio? get catalogo => _catalogo;
  bool get cargando => _cargando;
  bool get cargado => _catalogo != null;
  bool get disponible =>
      _catalogo != null &&
      _catalogo!.categorias.isNotEmpty &&
      _catalogo!.unidadesMedida.isNotEmpty;
  String? get errorMessage => _errorMessage;

  CatalogoVentaPersistido? get catalogoVenta => _catalogoVenta;
  bool get ventaCargada => _catalogoVenta != null;
  bool get cargandoVenta => _cargandoVenta;
  String? get ventaErrorMessage => _ventaErrorMessage;

  Future<void> cargar() {
    // El catálogo de venta se dispara también cuando el legacy viene
    // precargado: su estado de error es propio y nunca bloquea al otro.
    final venta = cargarVenta();
    if (_catalogo != null) return venta;
    final legacy = _cargaEnCurso ??= _cargar();
    return legacy;
  }

  Future<void> reintentar() {
    final legacy = _cargaEnCurso ?? cargar();
    final venta = _cargaVentaEnCurso ?? cargarVenta();
    return Future.wait([legacy, venta]);
  }

  Future<void> _cargar() async {
    _cargando = true;
    _errorMessage = null;
    _notificar();
    try {
      final catalogo = await _obtenerCatalogoNegocio(uid);
      if (_disposed) return;
      _catalogo = catalogo;
    } catch (error) {
      if (_disposed) return;
      _errorMessage = 'No se pudo cargar el catálogo del negocio: $error';
    } finally {
      _cargaEnCurso = null;
      if (!_disposed) {
        _cargando = false;
        _notificar();
      }
    }
  }

  Future<void> cargarVenta() {
    final useCase = _obtenerCatalogoVenta;
    if (useCase == null) return Future.value();
    if (_catalogoVenta != null) return Future.value();
    return _cargaVentaEnCurso ??= _cargarVenta(useCase);
  }

  Future<void> reintentarVenta() {
    _cargaVentaEnCurso = null;
    return cargarVenta();
  }

  Future<void> _cargarVenta(ObtenerCatalogoVenta useCase) async {
    _cargandoVenta = true;
    _ventaErrorMessage = null;
    _notificar();
    try {
      final catalogoVenta = await useCase(uid);
      if (_disposed) return;
      _catalogoVenta = catalogoVenta;
    } catch (error) {
      if (_disposed) return;
      _ventaErrorMessage = 'No se pudo cargar el catálogo de venta: $error';
    } finally {
      _cargaVentaEnCurso = null;
      if (!_disposed) {
        _cargandoVenta = false;
        _notificar();
      }
    }
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
