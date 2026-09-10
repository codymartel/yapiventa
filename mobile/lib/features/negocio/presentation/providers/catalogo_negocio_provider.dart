import 'package:flutter/foundation.dart';

import '../../application/use_cases/obtener_catalogo_negocio.dart';
import '../../domain/models/catalogo_negocio.dart';

class CatalogoNegocioProvider extends ChangeNotifier {
  final String uid;
  final ObtenerCatalogoNegocio _obtenerCatalogoNegocio;

  CatalogoNegocioProvider({
    required this.uid,
    required ObtenerCatalogoNegocio obtenerCatalogoNegocio,
    CatalogoNegocio? catalogoInicial,
  }) : _obtenerCatalogoNegocio = obtenerCatalogoNegocio,
       _catalogo = catalogoInicial;

  CatalogoNegocio? _catalogo;
  Future<void>? _cargaEnCurso;
  bool _cargando = false;
  bool _disposed = false;
  String? _errorMessage;

  CatalogoNegocio? get catalogo => _catalogo;
  bool get cargando => _cargando;
  bool get cargado => _catalogo != null;
  bool get disponible =>
      _catalogo != null &&
      _catalogo!.categorias.isNotEmpty &&
      _catalogo!.unidadesMedida.isNotEmpty;
  String? get errorMessage => _errorMessage;

  Future<void> cargar() {
    if (_catalogo != null) return Future.value();
    return _cargaEnCurso ??= _cargar();
  }

  Future<void> reintentar() {
    return _cargaEnCurso ?? cargar();
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

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
