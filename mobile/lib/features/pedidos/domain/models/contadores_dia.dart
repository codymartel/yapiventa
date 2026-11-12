// ═════════════════════════════════════════════════════════════════════════
// ItemContador · AporteVenta · ContadoresDia
// ═════════════════════════════════════════════════════════════════════════
// Los contadores que viajan dentro del resumen del día (un solo documento por
// día) para que los informes no lean pedido por pedido:
//
//   - por forma de pago, por tipo de entrega y por hora: céntimos vendidos;
//   - por producto, por variable (producto · modelo · fila) y por combo:
//     cantidad (en unidad base si se vende por medida) y céntimos, con el
//     nombre ya escrito para mostrar el ranking sin leer el producto.
//   - lo vendido en mostrador y lo anulado.
//
// Todo enteros. Los montos por producto son los de la línea, ANTES del
// descuento por forma de pago (el descuento no se reparte entre productos).
// ═════════════════════════════════════════════════════════════════════════
class ItemContador {
  const ItemContador({
    required this.nombre,
    this.cantidad = 0,
    this.centavos = 0,
  });

  final String nombre;
  final int cantidad;
  final int centavos;

  ItemContador mas(ItemContador otro) => ItemContador(
    nombre: otro.nombre.isEmpty ? nombre : otro.nombre,
    cantidad: cantidad + otro.cantidad,
    centavos: centavos + otro.centavos,
  );

  bool get vacio => cantidad <= 0 && centavos <= 0;
}

/// Lo que una venta aporta a los contadores del día.
class AporteVenta {
  const AporteVenta({
    required this.totalCentavos,
    this.esMostrador = false,
    this.entrega = '',
    this.hora = '',
    this.productos = const {},
    this.variantes = const {},
    this.combos = const {},
  });

  final int totalCentavos;
  final bool esMostrador;

  /// Claves normalizadas: entrega (local, recojo o delivery) y hora de Lima
  /// («09», «14»).
  final String entrega;
  final String hora;
  final Map<String, ItemContador> productos;
  final Map<String, ItemContador> variantes;
  final Map<String, ItemContador> combos;
}

class ContadoresDia {
  const ContadoresDia({
    this.mostradorCentavos = 0,
    this.mostrador = 0,
    this.anuladas = 0,
    this.anuladasCentavos = 0,
    this.porPago = const {},
    this.porEntrega = const {},
    this.porHora = const {},
    this.porProducto = const {},
    this.porVariante = const {},
    this.porCombo = const {},
    this.porCobrarCentavos = 0,
    this.porCobrar = 0,
  });

  /// Un día sin movimientos.
  static const ContadoresDia vacio = ContadoresDia();

  /// Venta de mostrador entregada ese día: cuántas y cuánto.
  final int mostradorCentavos;
  final int mostrador;

  /// Ventas anuladas ese día (de cualquier origen) y su monto.
  final int anuladas;
  final int anuladasCentavos;

  /// Lo COBRADO ese día por forma de pago (la plata entra el día en que se
  /// cobra, aunque el pedido se entregue otro día).
  final Map<String, int> porPago;

  /// Entregado ese día y todavía sin cobrar: monto y cuántos pedidos.
  final int porCobrarCentavos;
  final int porCobrar;

  final Map<String, int> porEntrega;
  final Map<String, int> porHora;
  final Map<String, ItemContador> porProducto;
  final Map<String, ItemContador> porVariante;
  final Map<String, ItemContador> porCombo;

  /// Los mismos contadores con otros cobros (lo demás no cambia).
  ContadoresDia conCobros({
    required Map<String, int> porPago,
    required int porCobrarCentavos,
    required int porCobrar,
  }) {
    return ContadoresDia(
      mostradorCentavos: mostradorCentavos,
      mostrador: mostrador,
      anuladas: anuladas,
      anuladasCentavos: anuladasCentavos,
      porPago: porPago,
      porEntrega: porEntrega,
      porHora: porHora,
      porProducto: porProducto,
      porVariante: porVariante,
      porCombo: porCombo,
      porCobrarCentavos: porCobrarCentavos,
      porCobrar: porCobrar,
    );
  }
}
