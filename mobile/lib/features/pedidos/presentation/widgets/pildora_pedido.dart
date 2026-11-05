import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/estado_pedido.dart';

/// Etiqueta corta de color: el estado del pedido («Nuevo», «Vencido»…). El
/// color nunca va solo: siempre lleva el texto.
class PildoraPedido extends StatelessWidget {
  const PildoraPedido({
    super.key,
    required this.texto,
    required this.color,
    this.icono,
  });

  /// La del estado; [vencido] la vuelve roja con el texto «Vencido».
  factory PildoraPedido.estado(EstadoPedido estado, {bool vencido = false}) {
    if (vencido) {
      return const PildoraPedido(texto: 'Vencido', color: AppColors.error);
    }
    return PildoraPedido(texto: estado.etiqueta, color: colorDe(estado));
  }

  final String texto;
  final Color color;
  final IconData? icono;

  static Color colorDe(EstadoPedido estado) {
    return switch (estado) {
      EstadoPedido.nuevo => AppColors.aviso,
      EstadoPedido.confirmado ||
      EstadoPedido.enCamino ||
      EstadoPedido.listo => AppColors.azulTexto,
      EstadoPedido.entregado => AppColors.ok,
      EstadoPedido.cancelado => AppColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
