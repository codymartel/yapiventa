import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

// ═════════════════════════════════════════════════════════════════════════
// UnidadRegistrada + RegistroUnidades
// ═════════════════════════════════════════════════════════════════════════
// Registro CERRADO de unidades visibles: solo se pueden usar estas, y sus
// conversiones a la unidad base son inmutables. No existen otras unidades.
//
// CONVERSIONES INMUTABLES (factorBase = cuántas unidades base hay en una):
//   - peso    : g (1),  kg (1000)     => 1 kg = 1000 g
//   - volumen : ml (1), L (1000)      => 1 L = 1000 ml
//   - longitud: mm (1), cm (10), m (1000) => 1 cm = 10 mm, 1 m = 1000 mm
//   - área    : cm² (1), m² (10000)   => 1 m² = 10000 cm²
//   - conteo  : unidad (1)
//
// La unidad base de cada familia es la de factorBase == 1:
// g, ml, mm, cm², unidad.
//
// UnidadRegistrada tiene constructor privado a propósito: es PROTEgida y
// no se puede instanciar desde fuera del catálogo.
// ═════════════════════════════════════════════════════════════════════════
class UnidadRegistrada {
  final String nombre;

  /// Cuántas unidades base contiene una unidad visible (int positivo).
  final int factorBase;

  const UnidadRegistrada._(this.nombre, this.factorBase);

  @override
  bool operator ==(Object other) =>
      other is UnidadRegistrada &&
      other.nombre == nombre &&
      other.factorBase == factorBase;

  @override
  int get hashCode => Object.hash(nombre, factorBase);

  @override
  String toString() => 'UnidadRegistrada($nombre, x$factorBase)';
}

class RegistroUnidades {
  RegistroUnidades._();

  // ── Peso ──────────────────────────────────────────────────────────────
  static const UnidadRegistrada g = UnidadRegistrada._('g', 1);
  static const UnidadRegistrada kg = UnidadRegistrada._('kg', 1000);

  // ── Volumen ───────────────────────────────────────────────────────────
  static const UnidadRegistrada ml = UnidadRegistrada._('ml', 1);
  static const UnidadRegistrada L = UnidadRegistrada._('L', 1000);

  // ── Longitud ──────────────────────────────────────────────────────────
  static const UnidadRegistrada mm = UnidadRegistrada._('mm', 1);
  static const UnidadRegistrada cm = UnidadRegistrada._('cm', 10);
  static const UnidadRegistrada m = UnidadRegistrada._('m', 1000);

  // ── Área ──────────────────────────────────────────────────────────────
  static const UnidadRegistrada cm2 = UnidadRegistrada._('cm²', 1);
  static const UnidadRegistrada m2 = UnidadRegistrada._('m²', 10000);

  // ── Conteo ────────────────────────────────────────────────────────────
  static const UnidadRegistrada unidad = UnidadRegistrada._('unidad', 1);

  /// Registro cerrado por familia.
  static const Map<FamiliaUnidad, List<UnidadRegistrada>> porFamilia = {
    FamiliaUnidad.peso: [g, kg],
    FamiliaUnidad.volumen: [ml, L],
    FamiliaUnidad.longitud: [mm, cm, m],
    FamiliaUnidad.area: [cm2, m2],
    FamiliaUnidad.conteo: [unidad],
  };

  /// Unidades habilitadas para la familia (lista no modificable).
  static List<UnidadRegistrada> unidadesDe(FamiliaUnidad familia) =>
      List.unmodifiable(porFamilia[familia]!);

  /// Unidad base (factorBase == 1) de la familia.
  static UnidadRegistrada baseDe(FamiliaUnidad familia) =>
      porFamilia[familia]!.firstWhere((unidad) => unidad.factorBase == 1);

  /// true si la unidad existe en el registro de esa familia.
  static bool esDeFamilia(UnidadRegistrada unidad, FamiliaUnidad familia) =>
      porFamilia[familia]?.contains(unidad) ?? false;

  /// true si la unidad es exactamente la base de la familia.
  static bool esBaseDe(UnidadRegistrada unidad, FamiliaUnidad familia) =>
      baseDe(familia) == unidad;

  /// Conversión inmutable a la unidad base (int puro):
  ///   1 kg → 1000, 1 L → 1000, 1 cm → 10, 1 m → 1000, 1 m² → 10000.
  static int convertirABase(int valorEnUnidad, UnidadRegistrada unidad) {
    if (valorEnUnidad <= 0) {
      throw ArgumentError.value(
        valorEnUnidad,
        'valorEnUnidad',
        'El valor debe ser un entero positivo.',
      );
    }
    return valorEnUnidad * unidad.factorBase;
  }
}
