// ═════════════════════════════════════════════════════════════════════════
// ValidadorModelos
// ═════════════════════════════════════════════════════════════════════════
// Reglas de los modelos y sus filas: límites del documento y avisos
// anti-duplicado ("Ya tienes Azul · M dos veces"). Función pura, sin Flutter.
//
// LÍMITES: todo vive en el documento del producto (tope de Firestore: 1 MiB).
// 30 modelos × 20 filas son ~600 filas ≈ 72 KB: lejos del tope.
// ═════════════════════════════════════════════════════════════════════════
class ValidadorModelos {
  ValidadorModelos._();

  static const int maxModelos = 30;
  static const int maxFilas = 20;

  /// El primer texto repetido (sin distinguir mayúsculas ni espacios de los
  /// bordes), tal como lo escribió la persona. null si no hay repetidos. Los
  /// vacíos no cuentan: ya los avisa el "Falta".
  static String? primerRepetido(Iterable<String> textos) {
    final vistos = <String>{};
    for (final texto in textos) {
      final limpio = texto.trim().toLowerCase();
      if (limpio.isEmpty) continue;
      if (!vistos.add(limpio)) return texto.trim();
    }
    return null;
  }
}
