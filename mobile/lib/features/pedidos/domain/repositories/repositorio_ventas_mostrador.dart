import '../models/descuento_stock.dart';
import '../models/linea_pedido.dart';
import '../models/pedido.dart';
import '../models/resumen_ventas_dia.dart';

// ═════════════════════════════════════════════════════════════════════════
// Venta de mostrador: lo que se pide al repositorio y lo que devuelve
// ═════════════════════════════════════════════════════════════════════════

/// Una venta de Caja lista para registrar. La cuenta ya viene calculada (en
/// céntimos enteros); el repositorio comprueba que cuadre y que los precios no
/// hayan cambiado.
class SolicitudVentaMostrador {
  const SolicitudVentaMostrador({
    required this.idVenta,
    required this.lineas,
    required this.tipoEntrega,
    this.enLocal = false,
    this.cliente = const ClientePedido(),
    this.zona = '',
    this.deliveryCentavos = 0,
    this.descuentoCentavos = 0,
    required this.subtotalCentavos,
    required this.totalCentavos,
    required this.metodoPago,
    this.notas = '',
    this.cobrarAlEntregar = false,
  });

  /// Identifica la venta desde que se empieza a armar: un segundo toque en
  /// «Cobrar» con el mismo id NO cobra dos veces.
  final String idVenta;
  final List<LineaPedido> lineas;
  final TipoEntrega tipoEntrega;

  /// Atendida en el local (se guarda como recojo).
  final bool enLocal;
  final ClientePedido cliente;
  final String zona;
  final int deliveryCentavos;
  final int descuentoCentavos;
  final int subtotalCentavos;
  final int totalCentavos;
  final String metodoPago;
  final String notas;

  /// Solo delivery: el pago queda pendiente hasta entregar.
  final bool cobrarAlEntregar;
}

/// Resultado de registrar una venta. Si no [registrada], no se escribió NADA.
class ResultadoVentaMostrador {
  const ResultadoVentaMostrador({
    this.pedidoId = '',
    this.clave = '',
    this.registrada = false,
    this.yaRegistrada = false,
    this.faltas = const [],
    this.sinProducto = const [],
    this.precioCambio = false,
    this.totalActualCentavos,
    this.lineasCambiadas = const [],
  });

  /// Id y clave del pedido (cuando se registró o ya estaba registrado).
  final String pedidoId;
  final String clave;

  /// Se escribió la venta en esta llamada.
  final bool registrada;

  /// Un toque repetido: la venta ya estaba registrada, no se hizo nada más.
  final bool yaRegistrada;

  /// Lo que no alcanza (nombre, pide, hay).
  final List<FaltaStock> faltas;

  /// Productos u opciones que ya no existen.
  final List<String> sinProducto;

  /// El precio de hoy no es el que vio el cajero: no se cobró, y con los
  /// precios de hoy el total sería [totalActualCentavos].
  final bool precioCambio;
  final int? totalActualCentavos;
  final List<String> lineasCambiadas;
}

/// Resultado de anular una venta entregada.
class ResultadoAnulacion {
  const ResultadoAnulacion({this.yaAnulada = false, this.sinDevolver = 0});

  /// Un toque repetido (u otro cajero): ya estaba anulada, no se tocó nada.
  final bool yaAnulada;

  /// Líneas cuyo stock no se pudo devolver porque el producto ya no existe.
  final int sinDevolver;
}

/// Registro de ventas de mostrador. La implementación vive en `data/`.
abstract class RepositorioVentasMostrador {
  /// Registra la venta en UNA transacción: crea el pedido, descuenta el stock
  /// y, si queda entregada, suma al resumen del día. Todo o nada.
  Future<ResultadoVentaMostrador> registrar(
    String negocioId,
    SolicitudVentaMostrador solicitud,
  );

  /// Anula una venta de Caja ya entregada, en UNA transacción: devuelve al
  /// stock lo que se descontó, resta del resumen del día de la venta y la deja
  /// cancelada (no se borra). Lanza [StateError] si no se puede anular.
  Future<ResultadoAnulacion> anular(String negocioId, String pedidoId);

  /// Los resúmenes diarios de [desde] a [hasta] (AAAA-MM-DD, ambos incluidos)
  /// con UNA consulta por rango. Un día sin ventas no tiene documento, así que
  /// no viene en la lista: se leen como máximo tantos documentos como días con
  /// ventas (tope 31). Lanza [ArgumentError] si el rango es inválido o pasa de
  /// 31 días.
  Future<List<ResumenVentasDia>> obtenerResumenes(
    String negocioId,
    String desde,
    String hasta,
  );
}
