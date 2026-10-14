import 'package:shared_preferences/shared_preferences.dart';

/// Guarda si la ayuda contextual de una sección ya se mostró una vez.
///
/// Clave por sección: `ayuda_vista_<seccion>` (p. ej. `ayuda_vista_inicio`).
/// Solo persiste un booleano; no toca contenido ni navegación.
class AyudaVistaService {
  static const _prefijo = 'ayuda_vista_';

  static String clavePara(String seccion) => '$_prefijo$seccion';

  final Future<SharedPreferences> Function()? _obtenerPrefs;

  AyudaVistaService({Future<SharedPreferences> Function()? obtenerPrefs})
    : _obtenerPrefs = obtenerPrefs; // ignore: prefer_initializing_formals

  Future<SharedPreferences> _prefs() {
    final obtener = _obtenerPrefs;
    if (obtener != null) return obtener();
    return SharedPreferences.getInstance();
  }

  Future<bool> yaVista(String seccion) async {
    final prefs = await _prefs();
    return prefs.getBool(clavePara(seccion)) ?? false;
  }

  Future<void> marcarVista(String seccion) async {
    final prefs = await _prefs();
    await prefs.setBool(clavePara(seccion), true);
  }
}
