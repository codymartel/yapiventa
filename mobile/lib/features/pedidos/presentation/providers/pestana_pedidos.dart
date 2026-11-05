import '../../domain/models/estado_pedido.dart';

/// Las pestañas de pedidos abiertos. Cada una escucha SU consulta de 10.
enum PestanaPedidos {
  nuevos('Nuevos', {EstadoPedido.nuevo}),
  activos('Activos', {
    EstadoPedido.confirmado,
    EstadoPedido.enCamino,
    EstadoPedido.listo,
  });

  const PestanaPedidos(this.etiqueta, this.estados);

  final String etiqueta;
  final Set<EstadoPedido> estados;
}
