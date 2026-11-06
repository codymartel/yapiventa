import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/services/transiciones_pedido.dart';
import '../../domain/models/pedido.dart';
import '../providers/pedidos_provider.dart';
import 'detalle_pedido.dart';

/// El detalle de un pedido siempre al día: se vuelve a buscar en el provider
/// cada vez que algo cambia. Si el pedido ya no está en las listas (se
/// entregó, se canceló), se cierra solo.
class DetalleVivoPedido extends StatelessWidget {
  const DetalleVivoPedido({
    super.key,
    required this.pedidoId,
    required this.reloj,
    required this.acciones,
    required this.onVacio,
    this.completo = false,
  });

  /// En PC el detalle muestra también el historial del pedido.
  final bool completo;
  final String pedidoId;
  final DateTime Function() reloj;
  final AccionesDetallePedido Function(Pedido) acciones;
  final VoidCallback onVacio;

  @override
  Widget build(BuildContext context) {
    return Consumer<PedidosProvider>(
      builder: (context, p, _) {
        final pedido = p.buscar(pedidoId);
        if (pedido == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onVacio());
          return const SizedBox.shrink();
        }
        final ahora = reloj();
        return DetallePedido(
          pedido: pedido,
          ahora: ahora,
          vencido: TransicionesPedido.estaVencido(pedido, ahora),
          procesando: p.procesando(pedido.id),
          acciones: acciones(pedido),
          completo: completo,
        );
      },
    );
  }
}
