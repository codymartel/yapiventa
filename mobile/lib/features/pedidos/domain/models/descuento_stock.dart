// ═════════════════════════════════════════════════════════════════════════
// DescuentoStock · FaltaStock
// ═════════════════════════════════════════════════════════════════════════
// [DescuentoStock] es lo que se descontó de UN lugar de stock al confirmar un
// pedido. Se guarda dentro del pedido: cancelar devuelve exactamente esto, no
// recalcula (regla de dominio). Un combo ya viene expandido a sus partes.
//
// [cantidad] está en la unidad en que vive ese stock: unidades enteras, o
// unidad base (g, ml…) cuando [enBase] es true.
// ═════════════════════════════════════════════════════════════════════════
class DescuentoStock {
  const DescuentoStock({
    required this.productoId,
    this.modeloId = '',
    this.filaId = '',
    required this.cantidad,
    this.enBase = false,
  });

  final String productoId;
  final String modeloId;
  final String filaId;
  final int cantidad;
  final bool enBase;

  /// Un mismo lugar de stock (producto · modelo · fila).
  String get clave => '$productoId|$modeloId|$filaId';
}

/// Lo que no alcanza al confirmar: se muestra al vendedor y no se descuenta nada.
class FaltaStock {
  const FaltaStock({
    required this.nombre,
    required this.pide,
    required this.hay,
  });

  final String nombre;
  final int pide;
  final int hay;
}
