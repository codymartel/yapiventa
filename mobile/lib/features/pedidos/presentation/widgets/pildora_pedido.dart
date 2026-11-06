import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/estado_pedido.dart';

/// Etiqueta corta de esquinas chicas, como en la maqueta: el estado del pedido
/// («Nuevo», «Vencido»…) o un dato neutro («Delivery», «Recojo»). El color
/// nunca va solo: siempre lleva el texto.
class PildoraPedido extends StatelessWidget {
  const PildoraPedido({
    super.key,
    required this.texto,
    required this.color,
    this.icono,
    this.escala = 1,
  });

  /// La del estado; [vencido] la vuelve roja con el texto «Vencido».
  factory PildoraPedido.estado(
    EstadoPedido estado, {
    bool vencido = false,
    double escala = 1,
  }) {
    if (vencido) {
      return PildoraPedido(
        texto: 'Vencido',
        color: AppColors.error,
        escala: escala,
      );
    }
    return PildoraPedido(
      texto: estado.etiqueta,
      color: colorDe(estado),
      escala: escala,
    );
  }

  /// Dato neutro (gris): tipo de entrega, etc.
  const PildoraPedido.neutra({
    super.key,
    required this.texto,
    this.icono,
    this.escala = 1,
  }) : color = AppColors.muted;

  final String texto;
  final Color color;
  final IconData? icono;

  /// 1 normal; mayor en TV.
  final double escala;

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
    final neutra = color == AppColors.muted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * escala, vertical: 1.5),
      decoration: BoxDecoration(
        color: neutra
            ? Colors.white.withValues(alpha: 0.07)
            : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 11 * escala, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5 * escala,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
