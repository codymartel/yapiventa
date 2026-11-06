// ═════════════════════════════════════════════════════════════════════════
// LineaPedido · ExtraLinea
// ═════════════════════════════════════════════════════════════════════════
// Una línea del carrito: producto · modelo · fila, con su cantidad y su
// precio TAL COMO ESTABAN al pedir (el pedido guarda nombre y precio propios:
// si después se borra o cambia el producto, el pedido no se rompe).
//
// Todo en enteros:
//   - [cantidad]: unidades si el producto se cuenta; unidad BASE (g, ml, mm,
//     cm²) si se vende por medida.
//   - [precioCentavos]: precio de UNA unidad (se cuenta) o de
//     [cantidadReferencia] unidades base (por medida: S/ 24,00 por 1 000 g).
// ═════════════════════════════════════════════════════════════════════════
class ExtraLinea {
  const ExtraLinea({required this.nombre, this.precioCentavos = 0});

  final String nombre;
  final int precioCentavos;
}

class LineaPedido {
  const LineaPedido({
    required this.productoId,
    this.modeloId = '',
    this.filaId = '',
    required this.nombre,
    this.etiqueta = '',
    required this.cantidad,
    required this.precioCentavos,
    this.porMedida = false,
    this.cantidadReferencia = 1,
    this.extras = const [],
    this.subtotalCentavos = 0,
    this.esCombo = false,
  });

  final String productoId;
  final String modeloId;
  final String filaId;

  /// Nombre del producto al pedir («Queso andino»).
  final String nombre;

  /// Modelo y fila legibles («Luna · M»); vacío si el producto es simple.
  final String etiqueta;
  final int cantidad;
  final int precioCentavos;
  final bool porMedida;

  /// Solo por medida: cuántas unidades base cubre [precioCentavos].
  final int cantidadReferencia;
  final List<ExtraLinea> extras;

  /// Lo que calculó la tienda al pedir (foto del momento). El panel lo
  /// recalcula con CalculoPedido y avisa si no coincide.
  final int subtotalCentavos;

  /// La línea es un combo (sus partes se descuentan una a una). Los pedidos
  /// viejos no lo traen: no son combos.
  final bool esCombo;

  LineaPedido copyWith({
    int? precioCentavos,
    int? cantidadReferencia,
    int? subtotalCentavos,
  }) {
    return LineaPedido(
      productoId: productoId,
      modeloId: modeloId,
      filaId: filaId,
      nombre: nombre,
      etiqueta: etiqueta,
      cantidad: cantidad,
      precioCentavos: precioCentavos ?? this.precioCentavos,
      porMedida: porMedida,
      cantidadReferencia: cantidadReferencia ?? this.cantidadReferencia,
      extras: extras,
      subtotalCentavos: subtotalCentavos ?? this.subtotalCentavos,
      esCombo: esCombo,
    );
  }
}
