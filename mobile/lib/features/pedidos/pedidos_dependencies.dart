import 'application/use_cases/avanzar_pedido.dart';
import 'application/use_cases/cancelar_pedido.dart';
import 'application/use_cases/cancelar_vencidos.dart';
import 'application/use_cases/confirmar_pedido.dart';
import 'application/use_cases/marcar_pago_pedido.dart';
import 'application/use_cases/marcar_reembolso_pedido.dart';
import 'data/pedidos_repository.dart';
import 'domain/repositories/repositorio_pedidos.dart';
import 'presentation/providers/historial_pedidos_provider.dart';
import 'presentation/providers/pedidos_provider.dart';

/// Arma, en un solo lugar, el repositorio y los casos de uso de Pedidos (igual
/// que `ProductosDependencies`). El tablero solo le pasa esto a la pantalla.
class PedidosDependencies {
  const PedidosDependencies({
    required this.repositorio,
    required this.confirmarPedido,
    required this.cancelarPedido,
    required this.avanzarPedido,
    required this.marcarPagoPedido,
    required this.marcarReembolsoPedido,
    required this.cancelarVencidos,
  });

  factory PedidosDependencies.production() {
    final repositorio = PedidosRepository();
    return PedidosDependencies.conRepositorio(repositorio);
  }

  factory PedidosDependencies.conRepositorio(RepositorioPedidos repositorio) {
    return PedidosDependencies(
      repositorio: repositorio,
      confirmarPedido: ConfirmarPedido(repositorio),
      cancelarPedido: CancelarPedido(repositorio),
      avanzarPedido: AvanzarPedido(repositorio),
      marcarPagoPedido: MarcarPagoPedido(repositorio),
      marcarReembolsoPedido: MarcarReembolsoPedido(repositorio),
      cancelarVencidos: CancelarVencidos(repositorio),
    );
  }

  final RepositorioPedidos repositorio;
  final ConfirmarPedido confirmarPedido;
  final CancelarPedido cancelarPedido;
  final AvanzarPedido avanzarPedido;
  final MarcarPagoPedido marcarPagoPedido;
  final MarcarReembolsoPedido marcarReembolsoPedido;
  final CancelarVencidos cancelarVencidos;

  PedidosProvider crearProvider(
    String negocioId, {
    DateTime Function()? reloj,
  }) {
    return PedidosProvider(
      negocioId: negocioId,
      repositorio: repositorio,
      confirmarPedido: confirmarPedido,
      cancelarPedido: cancelarPedido,
      avanzarPedido: avanzarPedido,
      marcarPagoPedido: marcarPagoPedido,
      marcarReembolsoPedido: marcarReembolsoPedido,
      cancelarVencidos: cancelarVencidos,
      reloj: reloj,
    );
  }

  HistorialPedidosProvider crearHistorial(String negocioId) {
    return HistorialPedidosProvider(
      negocioId: negocioId,
      repositorio: repositorio,
    );
  }
}
