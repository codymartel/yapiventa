import 'package:flutter/foundation.dart';

import '../../data/apariencia_repository.dart';
import '../../domain/tamano_letra.dart';

/// Estado de la apariencia de la app (hoy, el tamaño de letra). Vive arriba
/// de todo, en `main.dart`, para que el cambio se vea en todas las pantallas.
class AparienciaProvider extends ChangeNotifier {
  final AparienciaRepository _repository;
  TamanoLetra _tamanoLetra;

  AparienciaProvider({
    AparienciaRepository? repository,
    TamanoLetra tamanoLetra = TamanoLetra.normal,
  }) : _repository = repository ?? AparienciaRepository(),
       // Un parámetro con nombre no puede ser privado.
       _tamanoLetra = tamanoLetra; // ignore: prefer_initializing_formals

  /// Lee lo guardado antes de abrir la app: así la primera pantalla ya sale
  /// con la letra elegida, sin saltar de tamaño.
  static Future<AparienciaProvider> cargar([
    AparienciaRepository? repository,
  ]) async {
    final repo = repository ?? AparienciaRepository();
    final tamano = await repo.leerTamanoLetra();
    return AparienciaProvider(repository: repo, tamanoLetra: tamano);
  }

  TamanoLetra get tamanoLetra => _tamanoLetra;

  /// Cambia al instante y lo guarda. Si no se puede guardar, el cambio vale
  /// igual mientras la app siga abierta.
  Future<void> cambiarTamanoLetra(TamanoLetra tamano) async {
    if (tamano == _tamanoLetra) return;
    _tamanoLetra = tamano;
    notifyListeners();
    await _repository.guardarTamanoLetra(tamano);
  }
}
