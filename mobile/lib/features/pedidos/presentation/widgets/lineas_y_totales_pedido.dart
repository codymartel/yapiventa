import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/texto_lineas_pedido.dart';
import '../../application/services/verificacion_total_pedido.dart';
import '../../domain/models/pedido.dart';

/// Lo que pidió el cliente, línea por línea, y la cuenta. El importe de cada
/// línea se calcula con las mismas fórmulas de la tienda (céntimos enteros).
class LineasYTotalesPedido extends StatelessWidget {
  const LineasYTotalesPedido({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final linea in pedido.lineas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    TextoLineasPedido.cantidad(linea),
                    style: const TextStyle(
                      color: AppColors.azulTexto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TextoLineasPedido.nombre(linea),
                        style: const TextStyle(color: AppColors.texto),
                      ),
                      for (final extra in linea.extras)
                        Text(
                          '+ ${extra.nombre}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  MensajesAccionPedido.dinero(
                    CalculoPedido.subtotalLinea(linea),
                  ),
                  style: const TextStyle(color: AppColors.texto),
                ),
              ],
            ),
          ),
        const Divider(color: AppColors.dim, height: 20),
        _Fila('Subtotal', pedido.subtotalCentavos),
        if (pedido.deliveryCentavos > 0)
          _Fila(
            pedido.zona.trim().isEmpty
                ? 'Delivery'
                : 'Delivery · ${pedido.zona.trim()}',
            pedido.deliveryCentavos,
          ),
        if (pedido.descuentoCentavos > 0)
          _Fila('Descuento', -pedido.descuentoCentavos),
        _Fila('TOTAL', pedido.totalCentavos, fuerte: true),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.texto, this.centavos, {this.fuerte = false});

  final String texto;
  final int centavos;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      color: fuerte ? AppColors.texto : AppColors.muted,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w400,
      fontSize: fuerte ? 16 : 14,
    );
    final importe = centavos < 0
        ? '− ${MensajesAccionPedido.dinero(-centavos)}'
        : MensajesAccionPedido.dinero(centavos);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(texto, style: estilo)),
          Text(importe, style: estilo),
        ],
      ),
    );
  }
}
