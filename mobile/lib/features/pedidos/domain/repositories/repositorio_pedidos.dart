import '../models/descuento_stock.dart';
import '../models/estado_pedido.dart';
import '../models/pedido.dart';

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
  });

  /// Lo que no alcanza (nombre, pide, hay).
  final List<FaltaStock> faltas;

  /// Productos u opciones que ya no existen.
  final List<String> sinProducto;

  /// Otro vendedor ya lo confirmó o lo canceló.
  final bool yaNoEsNuevo;

  bool get ok => faltas.isEmpty && sinProducto.isEmpty && !yaNoEsNuevo;
}

/// Acceso a los pedidos de un negocio. La implementación vive en `data/`.
abstract class RepositorioPedidos {
  /// Escucha los pedidos abiertos (nuevo, confirmado, en camino, listo),
  /// del más nuevo al más viejo. 1 listener acotado a [limite] documentos.
  Stream<List<Pedido>> escucharAbiertos(String negocioId, {int limite = 50});

  /// Historial (entregados y cancelados) por páginas, solo cuando se abre.
  Future<PaginaPedidos> obtenerHistorial(
    String negocioId, {
    CursorPedidos? despuesDe,
    int limite = 20,
  });

  /// Transacción: valida que siga nuevo, descuenta el stock y confirma.
  /// Todo o nada.
  Future<ResultadoConfirmar> confirmar(String negocioId, String pedidoId);

  /// Transacción: cancela y devuelve al stock lo que se había descontado.
  /// Devuelve cuántas líneas no se pudieron devolver (producto borrado).
  Future<int> cancelar(
    String negocioId,
    String pedidoId, {
    bool reembolsoPendiente = false,
  });

  /// Cambia al estado siguiente (en camino, listo, entregado).
  Future<void> avanzar(String negocioId, String pedidoId, EstadoPedido nuevo);

  Future<void> marcarPago(String negocioId, String pedidoId, EstadoPago pago);

  Future<void> marcarReembolsoHecho(String negocioId, String pedidoId);
}
