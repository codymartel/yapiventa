import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/configuracion_negocio_provider.dart';

/// «Guardar y volver al producto»: solo aparece en el paso Catálogo cuando se
/// llegó desde el formulario de un producto. Guarda el catálogo (la misma
/// escritura de «Siguiente») y, si salió bien, vuelve al producto que quedó a
/// medias. Con un fallo no se va: el motivo queda en la barra.
class BotonVolverAlProducto extends StatelessWidget {
  const BotonVolverAlProducto({
    super.key,
    required this.uid,
    required this.onVolverAlProducto,
  });

  final String uid;
  final VoidCallback onVolverAlProducto;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    final ocupado = p.guardando || p.guardandoAvance;
    return OutlinedButton.icon(
      key: const Key('guardar-y-volver-al-producto'),
      onPressed: ocupado
          ? null
          : () async {
              final ok = await p.guardarAvanceCatalogoVenta(uid);
              if (ok && context.mounted) onVolverAlProducto();
            },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: AppColors.texto,
        side: BorderSide(color: AppColors.bordeMedio),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.undo, size: 18),
      label: const Text('Guardar y volver al producto'),
    );
  }
}
