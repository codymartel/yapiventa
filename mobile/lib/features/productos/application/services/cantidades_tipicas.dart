import '../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../domain/models/familia_unidad.dart';

// ═════════════════════════════════════════════════════════════════════════
// CantidadesTipicas
// ═════════════════════════════════════════════════════════════════════════
// Las cantidades que el vendedor elige en el menú "Por" del precio de un
// producto por medida (1 kg · ½ kg · ¼ kg · 100 g), y la etiqueta con que se
// muestra cualquier cantidad en el formulario y en la tarjeta. Función pura,
// sin Flutter. Todo en enteros de la unidad base (g, ml, mm, cm²).
//
// Las etiquetas usan ½ ¼ ¾ solo para mostrar. No se guardan: lo guardado es
// siempre el entero en unidad base.
// ═════════════════════════════════════════════════════════════════════════

/// Una cantidad del menú "Por": su valor en unidad base y cómo se lee.
class CantidadTipica {
  const CantidadTipica(this.base, this.etiqueta);

  final int base;
  final String etiqueta;
}

class CantidadesTipicas {
  CantidadesTipicas._();

  static const _basesPorFamilia = <FamiliaUnidad, List<int>>{
    FamiliaUnidad.peso: [1000, 500, 250, 100],
    FamiliaUnidad.volumen: [1000, 500, 250, 100],
    FamiliaUnidad.longitud: [1000, 500, 100],
    FamiliaUnidad.area: [10000],
  };

  /// Cantidades del menú "Por" de la familia (vacío para conteo).
  static List<CantidadTipica> de(FamiliaUnidad familia) => [
    for (final base in _basesPorFamilia[familia] ?? const <int>[])
      CantidadTipica(base, etiqueta(familia, base)),
  ];

  /// La cantidad típica con ese valor; null si no es una del menú.
  static CantidadTipica? coincidente(FamiliaUnidad familia, int base) {
    for (final tipica in de(familia)) {
      if (tipica.base == base) return tipica;
    }
    return null;
  }

  /// Unidad más grande de la familia (kg, L, m, m²).
  static UnidadRegistrada unidadGrande(FamiliaUnidad familia) {
    return _unidadesDeMayorAMenor(familia).first;
  }

  /// La unidad más grande en que [base] se expresa en enteros (2000 g → kg,
  /// 300 g → g). Es la que se propone al reabrir una "otra cantidad".
  static UnidadRegistrada unidadNatural(FamiliaUnidad familia, int base) {
    final unidades = _unidadesDeMayorAMenor(familia);
    for (final unidad in unidades) {
      if (base > 0 && base % unidad.factorBase == 0) return unidad;
    }
    return unidades.last;
  }

  /// Cómo se lee una cantidad: "1 kg", "¼ kg", "1½ kg", "100 g", "10 cm".
  /// Prueba de la unidad más grande a la más chica: primero enteros, luego
  /// cuartos. Si nada calza usa la unidad base. '' si [base] no es positivo.
  static String etiqueta(FamiliaUnidad familia, int base) {
    if (base <= 0) return '';
    final unidades = _unidadesDeMayorAMenor(familia);
    for (final unidad in unidades) {
      final factor = unidad.factorBase;
      if (base % factor == 0) return '${base ~/ factor} ${unidad.nombre}';
      if (factor % 4 != 0) continue;
      final cuarto = factor ~/ 4;
      if (base % cuarto != 0) continue;
      final cuartos = base ~/ cuarto;
      final enteros = cuartos ~/ 4;
      final fraccion = const {1: '¼', 2: '½', 3: '¾'}[cuartos % 4]!;
      return '${enteros == 0 ? '' : enteros}$fraccion ${unidad.nombre}';
    }
    return '$base ${unidades.last.nombre}';
  }

  static List<UnidadRegistrada> _unidadesDeMayorAMenor(FamiliaUnidad familia) {
    return RegistroUnidades.unidadesDe(familia).toList()
      ..sort((a, b) => b.factorBase.compareTo(a.factorBase));
  }
}
