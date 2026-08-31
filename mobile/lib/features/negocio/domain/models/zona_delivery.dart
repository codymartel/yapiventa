// ═════════════════════════════════════════════════════════════════════════
// ZonaDelivery
// ═════════════════════════════════════════════════════════════════════════
// Migración directa de tu `data class ZonaDelivery(var zona, var costo)`.
// En Kotlin eran `var` (mutables) porque los editabas en el diálogo antes
// de guardar. Aquí lo mantenemos simple con `copyWith` para "editar" sin
// mutar el objeto directamente — más seguro con el patrón de estado de
// Flutter (ChangeNotifier no detecta bien mutaciones internas, prefiere
// que le des un objeto nuevo).
// ═════════════════════════════════════════════════════════════════════════

class ZonaDelivery {
  final String zona;
  final String costo;

  const ZonaDelivery({required this.zona, required this.costo});

  ZonaDelivery copyWith({String? zona, String? costo}) {
    return ZonaDelivery(
      zona: zona ?? this.zona,
      costo: costo ?? this.costo,
    );
  }
}