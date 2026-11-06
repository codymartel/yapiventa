import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/texto_lineas_pedido.dart';
import '../../application/services/verificacion_total_pedido.dart';
import '../../domain/models/pedido.dart';

/// Lo que pidió el cliente, línea por línea (cada una en su cajita con la
/// cantidad destacada, como en la maqueta) y la cuenta. El importe de cada
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
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.fondo,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blueLt.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    TextoLineasPedido.cantidad(linea),
                    style: const TextStyle(
                      color: AppColors.azulTexto,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TextoLineasPedido.nombre(linea),
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 13,
                        ),
                      ),
                      for (final extra in linea.extras)
                        Text(
                          '+ ${extra.nombre}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  MensajesAccionPedido.dinero(
                    CalculoPedido.subtotalLinea(linea),
                  ),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
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
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Divider(height: 1, color: AppColors.dim),
              ),
              _Fila('TOTAL', pedido.totalCentavos, fuerte: true),
            ],
          ),
        ),
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
    final importe = centavos < 0
        ? '− ${MensajesAccionPedido.dinero(-centavos)}'
        : MensajesAccionPedido.dinero(centavos);
    return Padding(
      padding: EdgeInsets.only(top: fuerte ? 6 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                color: fuerte ? AppColors.texto : AppColors.muted,
                fontWeight: fuerte ? FontWeight.w800 : FontWeight.w400,
                fontSize: fuerte ? 16 : 13,
              ),
            ),
          ),
          Text(
            importe,
            style: TextStyle(
              // El total va en verde, como en la maqueta.
              color: fuerte ? AppColors.ok : AppColors.muted,
              fontWeight: fuerte ? FontWeight.w800 : FontWeight.w400,
              fontSize: fuerte ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
