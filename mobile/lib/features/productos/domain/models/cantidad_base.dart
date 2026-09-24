import 'familia_unidad.dart';

// ═════════════════════════════════════════════════════════════════════════
// CantidadBase
// ═════════════════════════════════════════════════════════════════════════
// Cantidad atómica del dominio: un entero positivo en la unidad BASE de su
// familia. NUNCA usa double y NUNCA guarda la unidad comercial elegida por
// el usuario (g/kg, ml/L...) — ese es el trabajo de la UI al convertir.
//
// UNIDADES INTERNAS (los valores que se almacenan):
//   - conteo  -> unidades
//   - peso    -> gramos        (1½ kg se convierte a 1500 ANTES de calcular)
//   - volumen -> mililitros
//   - longitud-> milímetros
//   - area    -> centímetros²
//
// La conversión de unidades comerciales a la base es responsabilidad
// futura de la capa de UI/formulario, no de este modelo: aquí nunca entra
// un "1.5" porque el entero base ya es el resultado de esa conversión.
//
// ALCANCE: solo valores positivos. El cero y negativos quedan fuera del
// dominio (el calculador los rechaza explícitamente como entrada).
// ═════════════════════════════════════════════════════════════════════════
class CantidadBase {
  final int valor;
  final FamiliaUnidad familia;

  const CantidadBase._(this.valor, this.familia);

  /// Unidades de conteo. La presentación (ej. "1 botella") se cuenta aquí.
  factory CantidadBase.unidades(int cantidad) {
    final valor = _exigirPositivo(cantidad, 'unidades');
    return CantidadBase._(valor, FamiliaUnidad.conteo);
  }

  /// Gramos. Es la unidad base interna de la familia peso.
  factory CantidadBase.gramos(int cantidad) {
    final valor = _exigirPositivo(cantidad, 'gramos');
    return CantidadBase._(valor, FamiliaUnidad.peso);
  }

  /// Mililitros. Es la unidad base interna de la familia volumen.
  factory CantidadBase.mililitros(int cantidad) {
    final valor = _exigirPositivo(cantidad, 'mililitros');
    return CantidadBase._(valor, FamiliaUnidad.volumen);
  }

  /// Milímetros. Es la unidad base interna de la familia longitud.
  factory CantidadBase.milimetros(int cantidad) {
    final valor = _exigirPositivo(cantidad, 'milimetros');
    return CantidadBase._(valor, FamiliaUnidad.longitud);
  }

  /// Centímetros cuadrados. Es la unidad base interna de la familia área.
  factory CantidadBase.centimetrosCuadrados(int cantidad) {
    final valor = _exigirPositivo(cantidad, 'centimetrosCuadrados');
    return CantidadBase._(valor, FamiliaUnidad.area);
  }

  static int _exigirPositivo(int valor, String nombre) {
    if (valor <= 0) {
      throw ArgumentError.value(
        valor,
        nombre,
        'La cantidad debe ser un entero positivo.',
      );
    }
    return valor;
  }

  /// Igualdad por familia y valor. No compara unidades de distinta familia.
  @override
  bool operator ==(Object otro) {
    return otro is CantidadBase &&
        otro.familia == familia &&
        otro.valor == valor;
  }

  @override
  int get hashCode => Object.hash(familia, valor);

  @override
  String toString() => 'CantidadBase($valor, $familia)';
}
