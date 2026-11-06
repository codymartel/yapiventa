import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import 'transiciones_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// IndicadoresPedidos
// ═════════════════════════════════════════════════════════════════════════
// Los números de arriba en PC y TV, sacados de los pedidos YA cargados
// (Nuevos y Activos): 0 lecturas. Por eso «Por cobrar» y los conteos son de lo
// cargado, no del negocio entero. Función pura, sin Flutter ni Firestore.
// ═════════════════════════════════════════════════════════════════════════
class IndicadoresPedidos {
  const IndicadoresPedidos({
    this.nuevos = 0,
    this.minutosDelNuevoMasViejo,
    this.activos = 0,
    this.enCamino = 0,
    this.vencidos = 0,
    this.porCobrarCentavos = 0,
    this.porCobrarPedidos = 0,
  });

  final int nuevos;

  /// Minutos que lleva esperando el pedido nuevo más viejo; null si no hay.
  final int? minutosDelNuevoMasViejo;
  final int activos;
  final int enCamino;

  /// Nuevos con más de 12 h sin confirmar.
  final int vencidos;
  final int porCobrarCentavos;
  final int porCobrarPedidos;

  static IndicadoresPedidos calcular({
    required List<Pedido> nuevos,
    required List<Pedido> activos,
    required DateTime ahora,
  }) {
    int? masViejo;
    var vencidos = 0;
    for (final pedido in nuevos) {
      if (TransicionesPedido.estaVencido(pedido, ahora)) vencidos++;
      final fecha = pedido.fecha;
      if (fecha == null) continue;
      final minutos = ahora.difference(fecha).inMinutes;
      final seguro = minutos < 0 ? 0 : minutos;
      if (masViejo == null || seguro > masViejo) masViejo = seguro;
    }
    var porCobrar = 0;
    var porCobrarN = 0;
    for (final pedido in [...nuevos, ...activos]) {
      if (pedido.estadoPago == EstadoPago.pendiente) {
        porCobrar += pedido.totalCentavos;
        porCobrarN++;
      }
    }
    return IndicadoresPedidos(
      nuevos: nuevos.length,
      minutosDelNuevoMasViejo: masViejo,
      activos: activos.length,
      enCamino: activos.where((p) => p.estado == EstadoPedido.enCamino).length,
      vencidos: vencidos,
      porCobrarCentavos: porCobrar,
      porCobrarPedidos: porCobrarN,
    );
  }
}
