import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tamano_letra.dart';

/// Guarda la apariencia de la app en el equipo (`shared_preferences`).
/// No toca Firebase: 0 lecturas y 0 escrituras.
///
/// Si el equipo no deja leer o guardar (navegador en modo privado, por
/// ejemplo), la app sigue con «Normal» sin mostrar errores.
class AparienciaRepository {
  static const claveTamanoLetra = 'apariencia_tamano_letra';

  final Future<SharedPreferences> Function() _obtenerPrefs;

  AparienciaRepository({Future<SharedPreferences> Function()? obtenerPrefs})
    : _obtenerPrefs = obtenerPrefs ?? SharedPreferences.getInstance;

  Future<TamanoLetra> leerTamanoLetra() async {
    try {
      final prefs = await _obtenerPrefs();
      return TamanoLetra.desdeClave(prefs.getString(claveTamanoLetra));
    } catch (_) {
      return TamanoLetra.normal;
    }
  }

  /// Devuelve si se pudo guardar.
  Future<bool> guardarTamanoLetra(TamanoLetra tamano) async {
    try {
      final prefs = await _obtenerPrefs();
      return await prefs.setString(claveTamanoLetra, tamano.clave);
    } catch (_) {
      return false;
    }
  }
}
