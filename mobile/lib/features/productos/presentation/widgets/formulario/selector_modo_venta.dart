import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/modo_venta.dart';

/// Selector de modo de venta. Solo ofrece los modos ACTIVOS en el catálogo
/// del negocio: si no hay medidas activas, la opción "Por medida" no
/// aparece. Un único modo disponible se muestra seleccionado y deshabilitado
/// (no hay nada que elegir).
class SelectorModoVenta extends StatelessWidget {
  const SelectorModoVenta({
    super.key,
    required this.modosDisponibles,
    required this.seleccionado,
    required this.onCambio,
  });

  final List<ModoVenta> modosDisponibles;
  final ModoVenta? seleccionado;
  final ValueChanged<ModoVenta> onCambio;

  static String etiqueta(ModoVenta modo) => switch (modo) {
    ModoVenta.presentacion => 'Por presentación',
    ModoVenta.medida => 'Por medida',
  };

  static String descripcion(ModoVenta modo) => switch (modo) {
    ModoVenta.presentacion => 'Se cuentan unidades, pares, botellas…',
    ModoVenta.medida => 'Se vende por peso, volumen… al granel',
  };

  @override
  Widget build(BuildContext context) {
    if (modosDisponibles.isEmpty) {
      return Text(
        'No hay formas de venta activas en tu catálogo.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ModoVenta>(
          segments: [
            for (final modo in modosDisponibles)
              ButtonSegment<ModoVenta>(
                value: modo,
                label: Text(etiqueta(modo)),
                tooltip: descripcion(modo),
              ),
          ],
          selected: seleccionado == null ||
                  !modosDisponibles.contains(seleccionado)
              ? <ModoVenta>{modosDisponibles.first}
              : <ModoVenta>{seleccionado!},
          onSelectionChanged: (seleccion) {
            if (seleccion.isEmpty) return;
            onCambio(seleccion.first);
          },
          showSelectedIcon: false,
        ),
        if (seleccionado != null &&
            modosDisponibles.contains(seleccionado)) ...[
          const SizedBox(height: 6),
          Text(
            descripcion(seleccionado!),
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
