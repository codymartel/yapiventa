import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Cuánto dura a la vista el aviso con «Anular» tras cobrar o gastar.
const Duration duracionAnularCaja = Duration(seconds: 8);

/// Muestra un aviso flotante de Caja (no tapa el botón de abajo). Con
/// [onAccion] trae un botón (por ejemplo «Anular») mientras dure el aviso.
/// Reemplaza al aviso anterior: nunca se apilan. Los textos se muestran como
/// texto plano.
void avisarCaja(
  BuildContext context,
  String mensaje, {
  String accion = 'Anular',
  VoidCallback? onAccion,
  bool error = false,
  Duration? duracion,
}) {
  if (mensaje.isEmpty) return;
  final mensajero = ScaffoldMessenger.maybeOf(context);
  if (mensajero == null) return;
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration:
            duracion ??
            (onAccion != null
                ? duracionAnularCaja
                : const Duration(seconds: 4)),
        backgroundColor: error ? AppColors.error : AppColors.texto,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              size: 20,
              color: AppColors.superficie,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: AppColors.superficie,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        action: onAccion == null
            ? null
            : SnackBarAction(
                label: accion,
                textColor: AppColors.blue,
                onPressed: onAccion,
              ),
      ),
    );
}
