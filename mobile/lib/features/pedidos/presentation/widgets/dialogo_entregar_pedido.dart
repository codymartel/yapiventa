import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';

/// Antes de entregar un pedido sin cobrar: «¿ya cobraste?» (el pago contra
/// entrega es común). Devuelve true = cobrado, false = todavía no, y null si
/// el vendedor se arrepiente. Si ya estaba pagado no pregunta: devuelve false
/// sin mostrar nada (no hay nada que marcar).
Future<bool?> mostrarDialogoEntregarPedido(
  BuildContext context,
  Pedido pedido,
) {
  if (pedido.estadoPago == EstadoPago.pagado) return Future.value(false);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.superficie,
      title: const Text(
        '¿Ya cobraste?',
        style: TextStyle(color: AppColors.texto),
      ),
      content: Text(
        'El pedido ${pedido.clave} es de '
        '${MensajesAccionPedido.dinero(pedido.totalCentavos)} y figura sin '
        'cobrar.',
        style: const TextStyle(color: AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Volver'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Entregar sin cobrar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sí, ya cobré'),
        ),
      ],
    ),
  );
}
