import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Desde este ancho el editor es un diálogo centrado; por debajo, una hoja que
/// sube desde abajo (mismo patrón de las demás ventanas).
const double anchoEditorEnDialogo = 900;

/// Abre [construir] como hoja desde abajo en celular o como diálogo centrado
/// en PC. El contenido recibe el contexto de la ventana: con él se cierra
/// (`Navigator.of(contexto).pop()`).
Future<void> abrirHojaODialogo(
  BuildContext context, {
  required Widget Function(BuildContext contexto) construir,
}) {
  final ancho = MediaQuery.sizeOf(context).width;

  if (ancho >= anchoEditorEnDialogo) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.superficie,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: construir(dialogContext),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.dim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            construir(sheetContext),
          ],
        ),
      ),
    ),
  );
}
