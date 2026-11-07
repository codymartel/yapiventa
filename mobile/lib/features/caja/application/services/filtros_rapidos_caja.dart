import 'package:mobile/features/productos/application/services/campos_catalogo_producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// FiltrosRapidosCaja
// ═════════════════════════════════════════════════════════════════════════
// Los chips de la fila rápida sobre la lista de Caja. Cambian según el rubro
// (maqueta B1), y «Frecuentes» va primero en todos:
//
//   Bodega       → por tipo: Simples · Por peso · Variables · Combos
//   Los demás    → sus categorías propias (hasta 5) y al final «Combos»
//
// Un toque aplica un solo filtro (tipo o categoría). Función pura.
// ═════════════════════════════════════════════════════════════════════════
class FiltroRapidoCaja {
  const FiltroRapidoCaja(this.etiqueta, {this.tipo, this.categoria});

  final String etiqueta;

  /// Uno de `CamposCatalogoProducto.tipos`, o null.
  final String? tipo;
  final String? categoria;

  /// «Frecuentes»: sin filtro (todos, los más vendidos primero).
  bool get esFrecuentes => tipo == null && categoria == null;

  bool estaActivo(String? tipoActual, String? categoriaActual) {
    if (esFrecuentes) return tipoActual == null && categoriaActual == null;
    if (tipo != null) return tipoActual == tipo && categoriaActual == null;
    return categoriaActual == categoria && tipoActual == null;
  }
}

abstract final class FiltrosRapidosCaja {
  /// Cuántas categorías propias caben en la fila (el resto va en «Avanzados»).
  static const int maximoCategorias = 5;

  static List<FiltroRapidoCaja> para({
    required String rubro,
    List<String> categorias = const [],
  }) {
    const frecuentes = FiltroRapidoCaja('Frecuentes');
    const combos = FiltroRapidoCaja(
      'Combos',
      tipo: CamposCatalogoProducto.tipoCombo,
    );
    if (rubro.trim().toLowerCase() == 'bodega') {
      return const [
        frecuentes,
        FiltroRapidoCaja('Simples', tipo: CamposCatalogoProducto.tipoSimple),
        FiltroRapidoCaja('Por peso', tipo: CamposCatalogoProducto.tipoMedida),
        FiltroRapidoCaja(
          'Variables',
          tipo: CamposCatalogoProducto.tipoVariable,
        ),
        combos,
      ];
    }
    final propias = <String>[];
    for (final c in categorias) {
      final limpia = c.trim();
      if (limpia.isEmpty || propias.contains(limpia)) continue;
      propias.add(limpia);
    }
    return [
      frecuentes,
      for (final c in propias.take(maximoCategorias))
        FiltroRapidoCaja(c, categoria: c),
      combos,
    ];
  }

  /// Cuántos filtros «avanzados» hay puestos (el número junto a «Avanzados»):
  /// «solo con stock» y una categoría que no es de la fila rápida.
  static int avanzadosActivos({
    required List<FiltroRapidoCaja> rapidos,
    String? categoria,
    bool soloConStock = false,
  }) {
    var n = soloConStock ? 1 : 0;
    if (categoria != null && !rapidos.any((f) => f.categoria == categoria)) {
      n++;
    }
    return n;
  }

  /// Las categorías que no caben en la fila rápida (van en «Avanzados»).
  static List<String> restantes(List<String> categorias) {
    final unicas = <String>[];
    for (final c in categorias) {
      final limpia = c.trim();
      if (limpia.isNotEmpty && !unicas.contains(limpia)) unicas.add(limpia);
    }
    return unicas.skip(maximoCategorias).toList();
  }
}
