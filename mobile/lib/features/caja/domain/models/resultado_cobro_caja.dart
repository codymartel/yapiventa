import '../../../pedidos/domain/models/descuento_stock.dart';

// ═════════════════════════════════════════════════════════════════════════
// TipoCobroCaja · ResultadoCobroCaja
// ═════════════════════════════════════════════════════════════════════════
// Lo que devuelve un intento de cobrar en Caja: cómo terminó, el mensaje para
// el cajero y, si se registró, los datos de la venta (para «Anular»).
// ═════════════════════════════════════════════════════════════════════════
/// Cómo terminó un intento de cobrar.
enum TipoCobroCaja {
  /// Se registró la venta.
  exito,

  /// Un toque repetido: ya estaba registrada, no se cobró de nuevo.
  yaRegistrada,

  /// Faltan datos o sobran caracteres: no se intentó cobrar.
  faltanDatos,

  /// El stock, un producto o los precios lo impiden: no se escribió nada.
  bloqueado,

  /// Sin conexión u otro fallo: se puede reintentar sin cobrar dos veces.
  error,

  /// Ya había un cobro en curso (doble toque) o las ventas están bloqueadas.
  ignorado,
}

class ResultadoCobroCaja {
  const ResultadoCobroCaja(
    this.tipo, {
    this.mensaje = '',
    this.pedidoId = '',
    this.clave = '',
    this.totalCentavos = 0,
    this.descuentos = const [],
  });

  final TipoCobroCaja tipo;
  final String mensaje;

  /// De la venta registrada (para «Anular» en el aviso).
  final String pedidoId;
  final String clave;
  final int totalCentavos;

  /// Lo que la venta descontó del stock: la lista lo resta en memoria y, si
  /// se anula desde el aviso, lo devuelve (sin releer el catálogo).
  final List<DescuentoStock> descuentos;

  bool get registrada =>
      tipo == TipoCobroCaja.exito || tipo == TipoCobroCaja.yaRegistrada;
}
