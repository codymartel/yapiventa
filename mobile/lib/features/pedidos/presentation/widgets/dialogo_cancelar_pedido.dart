import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';

/// Pide confirmar antes de cancelar. Dice qué pasará con el stock y con el
/// dinero. Devuelve true solo si el vendedor confirma.
Future<bool> mostrarDialogoCancelarPedido(
  BuildContext context,
  Pedido pedido,
) async {
  final avisos = <String>[
    if (pedido.estado == EstadoPedido.confirmado)
      'Se devolverá al stock lo que se descontó al confirmar.',
    if (pedido.estadoPago == EstadoPago.pagado)
      'Ya estaba pagado: quedará un reembolso pendiente.',
  ];
  final confirmo = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.superficie,
      title: Text(
        '¿Cancelar el pedido ${pedido.clave}?',
        style: const TextStyle(color: AppColors.texto),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El pedido no se borra: queda en el historial como cancelado.',
            style: TextStyle(color: AppColors.muted),
          ),
          for (final aviso in avisos)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                aviso,
                style: const TextStyle(color: AppColors.aviso),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Cancelar pedido'),
        ),
      ],
    ),
  );
  return confirmo ?? false;
}

/// Pide confirmar antes de cancelar los vencidos.
Future<bool> mostrarDialogoCancelarVencidos(
  BuildContext context,
  int cantidad,
) async {
  final confirmo = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.superficie,
      title: Text(
        cantidad == 1
            ? '¿Cancelar el pedido vencido?'
            : '¿Cancelar los pedidos vencidos?',
        style: const TextStyle(color: AppColors.texto),
      ),
      content: const Text(
        'Son pedidos nuevos con más de 12 horas sin confirmar. No se borran: '
        'quedan en el historial como cancelados.',
        style: TextStyle(color: AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Cancelar vencidos'),
        ),
      ],
    ),
  );
  return confirmo ?? false;
}
