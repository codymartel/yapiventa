import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';

/// Los pasos del pedido: Nuevo → Confirmado → En camino (o Listo) → Entregado.
/// Un pedido cancelado no tiene barra: se avisa con texto.
class BarraProgresoPedido extends StatelessWidget {
  const BarraProgresoPedido({super.key, required this.pedido});

  final Pedido pedido;

  List<EstadoPedido> get _pasos => [
    EstadoPedido.nuevo,
    EstadoPedido.confirmado,
    pedido.tipoEntrega == TipoEntrega.recojo
        ? EstadoPedido.listo
        : EstadoPedido.enCamino,
    EstadoPedido.entregado,
  ];

  @override
  Widget build(BuildContext context) {
    if (pedido.estado == EstadoPedido.cancelado) {
      return const Text(
        'Pedido cancelado',
        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
      );
    }
    final pasos = _pasos;
    final actual = pasos.indexOf(pedido.estado);
    return Semantics(
      label: 'Paso ${actual + 1} de ${pasos.length}: ${pedido.estado.etiqueta}',
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < pasos.length; i++) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= actual ? AppColors.blueLt : AppColors.dim,
                  ),
                ),
                if (i < pasos.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < actual ? AppColors.blueLt : AppColors.dim,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < pasos.length; i++)
                // Flexible + escala: con letra grande el texto se achica, no se sale.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      pasos[i].etiqueta,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == actual
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: i == actual ? AppColors.texto : AppColors.hint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
