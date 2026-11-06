import 'descuento_stock.dart';
import 'estado_pedido.dart';
import 'linea_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// Pedido
// ═════════════════════════════════════════════════════════════════════════
// Un pedido de la tienda pública. Vive en negocios/{negocioId}/pedidos/{id}.
// Dinero en CÉNTIMOS enteros; nada se borra nunca (se cancela).
//
// [stockDescontado] se llena SOLO al confirmar y es lo que cancelar devuelve.
// [historial] guarda cada cambio de estado dentro del mismo documento: 0
// lecturas extra.
// ═════════════════════════════════════════════════════════════════════════
enum TipoEntrega {
  delivery('delivery'),
  recojo('recojo');

  const TipoEntrega(this.valor);

  final String valor;

  static TipoEntrega desdeValor(String? valor) {
    return valor == 'recojo' ? recojo : delivery;
  }
}

/// Quién registró el pedido: el cliente en la tienda web, o el vendedor en
/// Caja (venta de mostrador). Los pedidos viejos no lo traen: son de la tienda.
enum OrigenPedido {
  tienda('tienda'),
  mostrador('mostrador');

  const OrigenPedido(this.valor);

  final String valor;

  static OrigenPedido desdeValor(String? valor) {
    return valor == 'mostrador' ? mostrador : tienda;
  }
}

class ClientePedido {
  const ClientePedido({
    this.nombre = '',
    this.telefono = '',
    this.direccion = '',
    this.correo = '',
  });

  final String nombre;
  final String telefono;
  final String direccion;
  final String correo;
}

class CambioEstado {
  const CambioEstado({required this.estado, required this.fecha});

  final EstadoPedido estado;
  final DateTime fecha;
}

class Pedido {
  const Pedido({
    required this.id,
    this.clave = '',
    this.estado = EstadoPedido.nuevo,
    this.origen = OrigenPedido.tienda,
    this.tipoEntrega = TipoEntrega.delivery,
    this.enLocal = false,
    this.fecha,
    this.cliente = const ClientePedido(),
    this.zona = '',
    this.deliveryCentavos = 0,
    this.descuentoCentavos = 0,
    this.subtotalCentavos = 0,
    this.totalCentavos = 0,
    this.lineas = const [],
    this.metodoPago = '',
    this.estadoPago = EstadoPago.pendiente,
    this.notas = '',
    this.stockDescontado = const [],
    this.reembolso = EstadoReembolso.ninguno,
    this.historial = const [],
  });

  final String id;

  /// Clave corta que ve el cliente (6 caracteres, ej. 7GHMHF).
  final String clave;
  final EstadoPedido estado;
  final OrigenPedido origen;
  final TipoEntrega tipoEntrega;

  /// Venta de mostrador atendida en el local (el cliente se lleva el producto
  /// ahí mismo). Se guarda como «recojo»; este campo la distingue de un recojo.
  final bool enLocal;

  /// Momento en que llegó (hora del servidor). null mientras se escribe.
  final DateTime? fecha;
  final ClientePedido cliente;
  final String zona;
  final int deliveryCentavos;
  final int descuentoCentavos;
  final int subtotalCentavos;
  final int totalCentavos;
  final List<LineaPedido> lineas;
  final String metodoPago;
  final EstadoPago estadoPago;
  final String notas;
  final List<DescuentoStock> stockDescontado;
  final EstadoReembolso reembolso;
  final List<CambioEstado> historial;

  Pedido copyWith({
    EstadoPedido? estado,
    EstadoPago? estadoPago,
    EstadoReembolso? reembolso,
    List<DescuentoStock>? stockDescontado,
    List<CambioEstado>? historial,
  }) {
    return Pedido(
      id: id,
      clave: clave,
      estado: estado ?? this.estado,
      origen: origen,
      tipoEntrega: tipoEntrega,
      enLocal: enLocal,
      fecha: fecha,
      cliente: cliente,
      zona: zona,
      deliveryCentavos: deliveryCentavos,
      descuentoCentavos: descuentoCentavos,
      subtotalCentavos: subtotalCentavos,
      totalCentavos: totalCentavos,
      lineas: lineas,
      metodoPago: metodoPago,
      estadoPago: estadoPago ?? this.estadoPago,
      notas: notas,
      stockDescontado: stockDescontado ?? this.stockDescontado,
      reembolso: reembolso ?? this.reembolso,
      historial: historial ?? this.historial,
    );
  }
}
