import 'package:flutter/foundation.dart';

import '../../application/use_cases/guardar_plantilla_web.dart';
import '../../application/use_cases/obtener_seleccion_plantilla.dart';
import '../../domain/models/plantilla_web.dart';

class SeleccionPlantillaProvider extends ChangeNotifier {
  final String uid;
  final ObtenerSeleccionPlantilla obtenerSeleccionPlantilla;
  final GuardarPlantillaWeb guardarPlantillaWeb;

  SeleccionPlantillaProvider({
    required this.uid,
    required this.obtenerSeleccionPlantilla,
    required this.guardarPlantillaWeb,
  });

  String _slug = '';
  PlantillaWeb? _plantillaGuardada;
  PlantillaWeb? _seleccionTemporal;
  Future<void>? _cargaEnCurso;
  Future<bool>? _guardadoEnCurso;
  bool _cargando = false;
  bool _cargado = false;
  bool _guardando = false;
  bool _provieneDeCampoOficial = false;
  bool _disposed = false;
  String? _errorMessage;

  String get slug => _slug;
  PlantillaWeb? get plantillaGuardada => _plantillaGuardada;
  PlantillaWeb? get seleccionTemporal => _seleccionTemporal;
  bool get cargando => _cargando;
  bool get cargado => _cargado;
  bool get guardando => _guardando;
  String? get errorMessage => _errorMessage;
  bool get cambiosPendientes =>
      _seleccionTemporal != null &&
      (_seleccionTemporal != _plantillaGuardada || !_provieneDeCampoOficial);

  Future<void> cargar() {
    if (_cargado) return Future.value();
    return _cargaEnCurso ??= _cargar();
  }

  Future<void> recargar() {
    final cargaEnCurso = _cargaEnCurso;
    if (cargaEnCurso != null) return cargaEnCurso;
    _cargado = false;
    return _cargaEnCurso = _cargar();
  }

  Future<void> _cargar() async {
    _cargando = true;
    _errorMessage = null;
    _notificar();
    try {
      if (uid.isEmpty) throw StateError('No se encontro el usuario actual.');

      final info = await obtenerSeleccionPlantilla(uid);
      if (_disposed) return;
      _slug = info.slug;
      _plantillaGuardada = info.plantillaGuardada;
      _seleccionTemporal = info.plantillaGuardada;
      _provieneDeCampoOficial = info.provieneDeCampoOficial;
      _cargado = true;
    } catch (error) {
      if (_disposed) return;
      _errorMessage = 'No se pudo cargar la seleccion de plantilla: $error';
    } finally {
      _cargaEnCurso = null;
      if (!_disposed) {
        _cargando = false;
        _notificar();
      }
    }
  }

  void seleccionar(PlantillaWeb plantilla) {
    if (_cargando || _guardando || _seleccionTemporal == plantilla) return;
    _seleccionTemporal = plantilla;
    _errorMessage = null;
    _notificar();
  }

  Future<bool> guardar() {
    final guardadoEnCurso = _guardadoEnCurso;
    if (guardadoEnCurso != null) return guardadoEnCurso;

    final seleccion = _seleccionTemporal;
    if (!_cargado || seleccion == null) {
      _errorMessage = 'Selecciona una plantilla antes de guardar.';
      _notificar();
      return Future.value(false);
    }
    if (!cambiosPendientes) return Future.value(true);

    final futuro = _guardar(seleccion);
    _guardadoEnCurso = futuro;
    futuro.whenComplete(() {
      if (identical(_guardadoEnCurso, futuro)) _guardadoEnCurso = null;
    });
    return futuro;
  }

  Future<bool> _guardar(PlantillaWeb seleccion) async {
    _guardando = true;
    _errorMessage = null;
    _notificar();
    try {
      await guardarPlantillaWeb(uid, seleccion);
      if (_disposed) return false;
      _plantillaGuardada = seleccion;
      _seleccionTemporal = seleccion;
      _provieneDeCampoOficial = true;
      return true;
    } catch (error) {
      if (_disposed) return false;
      _errorMessage = 'No se pudo guardar la plantilla web: $error';
      return false;
    } finally {
      if (!_disposed) {
        _guardando = false;
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
