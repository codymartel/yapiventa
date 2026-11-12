import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/resumen_dia_pedidos.dart';
import '../../domain/models/pedido.dart';
import 'tarjeta_pedido.dart';

/// Un día del historial: cuánto se entregó, cuántos se cancelaron y sus
/// pedidos. [incompleto] avisa que el día puede tener más pedidos por cargar.
class TarjetaHistorialDia extends StatelessWidget {
  const TarjetaHistorialDia({
    super.key,
    required this.resumen,
    required this.ahora,
    required this.onAbrirPedido,
    this.incompleto = false,
  });

  final ResumenDia resumen;
  final DateTime ahora;
  final ValueChanged<Pedido> onAbrirPedido;
  final bool incompleto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ResumenDiaPedidos.etiquetaDia(resumen.dia),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${resumen.nEntregados} '
                '${resumen.nEntregados == 1 ? 'entregado' : 'entregados'} · '
                '${MensajesAccionPedido.dinero(resumen.entregadosCentavos)}',
                style: const TextStyle(color: AppColors.ok, fontSize: 13),
              ),
            ],
          ),
        ),
        if (resumen.nCancelados > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              resumen.nCancelados == 1
                  ? '1 cancelado'
                  : '${resumen.nCancelados} cancelados',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        if (incompleto)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Puede tener más pedidos: toca «Ver más».',
              style: TextStyle(color: AppColors.aviso, fontSize: 12),
            ),
          ),
        for (final pedido in resumen.pedidos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TarjetaPedido(
              pedido: pedido,
              ahora: ahora,
              vencido: false,
              onTap: () => onAbrirPedido(pedido),
            ),
          ),
      ],
    );
  }
}
