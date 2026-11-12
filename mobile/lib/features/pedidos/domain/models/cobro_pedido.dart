// ═════════════════════════════════════════════════════════════════════════
// CobroPedido · AjusteCobroDia · PlanCobro
// ═════════════════════════════════════════════════════════════════════════
// La plata de un pedido entra a la caja el día en que se COBRA (no el día en
// que se entrega). El pedido guarda en `cobro` dónde se sumó, para que
// cancelar o anular resten exactamente eso (no se recalcula):
//
//   dia          → día del resumen en el que se sumó a «porPago» ('' = aún no)
//   pago         → clave de la forma de pago («efectivo», «yape»…)
//   centavos     → lo que se sumó
//   porCobrarDia → día en que se entregó sin cobrar (quedó «por cobrar»)
//
// Un pedido viejo (de antes de este dato) no lo trae: es null.
// ═════════════════════════════════════════════════════════════════════════
class CobroPedido {
  const CobroPedido({
    this.dia = '',
    this.pago = '',
    this.centavos = 0,
    this.porCobrarDia = '',
  });

  final String dia;
  final String pago;
  final int centavos;
  final String porCobrarDia;

  /// La plata ya está sumada en la caja de [dia].
  bool get contado => dia.isNotEmpty;

  /// Se entregó sin cobrar y sigue «por cobrar» en [porCobrarDia].
  bool get pendiente => !contado && porCobrarDia.isNotEmpty;
}

/// Lo que un cobro suma (positivo) o resta (negativo) al resumen de un día.
class AjusteCobroDia {
  const AjusteCobroDia({
    required this.dia,
    this.pago = '',
    this.cobradoCentavos = 0,
    this.porCobrarCentavos = 0,
    this.porCobrar = 0,
    this.cobradoPedidoId = '',
  });

  final String dia;

  /// Clave de «porPago» que cambia, y cuánto.
  final String pago;
  final int cobradoCentavos;

  /// Cambio en lo entregado sin cobrar ese día (monto y cuántos).
  final int porCobrarCentavos;
  final int porCobrar;

  /// Con valor: ese pedido aparece como cobrado en los últimos entregados.
  final String cobradoPedidoId;
}

/// Qué hacer con la caja en un paso del pedido: los ajustes por día y el
/// `cobro` que se guarda en el pedido (null = el pedido no cambia ese dato).
class PlanCobro {
  const PlanCobro({this.ajustes = const [], this.cobro});

  static const PlanCobro nada = PlanCobro();

  final List<AjusteCobroDia> ajustes;
  final CobroPedido? cobro;

  /// Los días cuyo resumen hay que leer y escribir.
  Set<String> get dias => {for (final a in ajustes) a.dia};
}
