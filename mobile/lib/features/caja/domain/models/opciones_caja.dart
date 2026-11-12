import '../../../pedidos/domain/models/descuento_pago.dart';
import '../../../pedidos/domain/models/pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// OpcionPagoCaja · ZonaCaja · EntregaCaja
// ═════════════════════════════════════════════════════════════════════════
// Lo que Caja necesita de la configuración del negocio, ya en ENTEROS:
//   - las formas de pago activas, con su descuento (centésimas de punto si es
//     porcentaje, céntimos si es monto fijo);
//   - las zonas de delivery con su costo en céntimos.
// Quien lee la configuración (que guarda decimales en texto) convierte UNA
// sola vez a estos enteros; Caja nunca trabaja con decimales.
// ═════════════════════════════════════════════════════════════════════════
class OpcionPagoCaja {
  const OpcionPagoCaja({
    required this.id,
    required this.etiqueta,
    this.descuento = DescuentoPago.ninguno,
  });

  /// Lo que se guarda en la venta («efectivo», «yape», «plin»…).
  final String id;

  /// Lo que lee el cajero («Efectivo», «Yape»…).
  final String etiqueta;
  final DescuentoPago descuento;
}

class ZonaCaja {
  const ZonaCaja({required this.nombre, this.costoCentavos = 0});

  final String nombre;
  final int costoCentavos;
}

/// Dónde se entrega: «En el local» y «Recojo» se guardan como recojo (el local
/// además marca `enLocal`); delivery lleva cliente, zona y dirección. «Recojo»
/// solo lo ve el restaurante («Para llevar»); ver `TextosEntregaCaja`.
enum EntregaCaja {
  local('En el local'),
  recojo('Recojo'),
  delivery('Delivery');

  const EntregaCaja(this.etiqueta);

  final String etiqueta;

  TipoEntrega get tipo =>
      this == delivery ? TipoEntrega.delivery : TipoEntrega.recojo;

  bool get enLocal => this == local;
}
