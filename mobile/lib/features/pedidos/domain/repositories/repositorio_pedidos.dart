import '../models/descuento_stock.dart';
import '../models/estado_pedido.dart';
import '../models/pedido.dart';
import '../models/resumen_ventas_dia.dart';

/// Marca opaca para pedir la página siguiente del historial.
abstract class CursorPedidos {}

class PaginaPedidos {
  const PaginaPedidos({
    required this.pedidos,
    required this.ultimoCursor,
    required this.hayMas,
  });

  final List<Pedido> pedidos;
  final CursorPedidos? ultimoCursor;
  final bool hayMas;
}

/// Resultado de confirmar un pedido. Si no es [ok], no se descontó NADA.
class ResultadoConfirmar {
  const ResultadoConfirmar({
    this.faltas = const [],
    this.sinProducto = const [],
    this.yaNoEsNuevo = false,
    this.totalActualCentavos,
    this.lineasCambiadas = const [],
  });

  /// Lo que no alcanza (nombre, pide, hay).
  final List<FaltaStock> faltas;

  /// Productos u opciones que ya no existen.
  final List<String> sinProducto;

  /// Otro vendedor ya lo confirmó o lo canceló.
  final bool yaNoEsNuevo;

  /// Solo aviso (no bloquea): si con los precios de hoy el total sería otro.
  /// Se respeta el total que vio el cliente; null = coincide.
  final int? totalActualCentavos;
  final List<String> lineasCambiadas;

  bool get ok => faltas.isEmpty && sinProducto.isEmpty && !yaNoEsNuevo;
}

/// Acceso a los pedidos de un negocio. La implementación vive en `data/`.
abstract class RepositorioPedidos {
  /// Escucha los [limite] pedidos abiertos más nuevos, del más nuevo al más
  /// viejo. Con [estados] solo esos (una pestaña: Nuevos, o Activos =
  /// confirmado, en camino y listo); sin ellos, todos los abiertos.
  /// 1 listener acotado.
  /// Lanza [ArgumentError] si [estados] está vacío o incluye uno cerrado.
  Stream<List<Pedido>> escucharAbiertos(
    String negocioId, {
    Set<EstadoPedido>? estados,
    int limite = 10,
  });

  /// «Ver más»: los siguientes [limite] abiertos, más viejos que [despuesDe]
  /// (el último de la lista que se ve). Una lectura puntual, no en vivo.
  /// [PaginaPedidos.ultimoCursor] va siempre null: la siguiente página se pide
  /// con el último pedido de esta.
  Future<PaginaPedidos> obtenerAbiertosDespuesDe(
    String negocioId,
    Pedido despuesDe, {
    Set<EstadoPedido>? estados,
    int limite = 10,
  });

  /// Pedidos nuevos que llegaron antes de [antesDe] (vencidos), hasta
  /// [limite]. Una lectura puntual.
  Future<List<Pedido>> obtenerVencidos(
    String negocioId, {
    required DateTime antesDe,
    int limite = 10,
  });

  /// Historial (entregados y cancelados) por páginas, solo cuando se abre.
  Future<PaginaPedidos> obtenerHistorial(
    String negocioId, {
    CursorPedidos? despuesDe,
    int limite = 20,
  });

  /// Escucha el resumen de UN día (un solo documento: 1 lectura al abrir y
  /// 1 por cada cambio). [dia] es AAAA-MM-DD en hora de Lima. Si el día aún no
  /// tiene movimientos, emite un resumen vacío.
  Stream<ResumenVentasDia> escucharResumenDia(String negocioId, String dia);

  /// Transacción: valida que siga nuevo, descuenta el stock y confirma.
  /// Todo o nada.
  Future<ResultadoConfirmar> confirmar(String negocioId, String pedidoId);

  /// Transacción: cancela y devuelve al stock lo que se había descontado.
  /// Si el pedido ya estaba pagado queda con el reembolso pendiente.
  /// Devuelve cuántas líneas no se pudieron devolver (producto borrado).
  /// Lanza [StateError] si el pedido ya no se puede cancelar o, con
  /// [soloSiEstaNuevo], si ya no está nuevo (otro vendedor lo confirmó).
  Future<int> cancelar(
    String negocioId,
    String pedidoId, {
    bool soloSiEstaNuevo = false,
  });

  /// Cambia al estado siguiente (en camino, listo, entregado). Con [pago]
  /// marca también el pago en la misma transacción (entregar y cobrar).
  Future<void> avanzar(
    String negocioId,
    String pedidoId,
    EstadoPedido nuevo, {
    EstadoPago? pago,
  });

  Future<void> marcarPago(String negocioId, String pedidoId, EstadoPago pago);

  Future<void> marcarReembolsoHecho(String negocioId, String pedidoId);
}
