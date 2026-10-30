import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/modo_venta.dart';

/// Selector de modo de venta. Solo deja elegir los modos ACTIVOS en el
/// catálogo del negocio. Si no hay medidas activas, "Por medida" se muestra
/// apagado con el aviso de dónde activarla (en vez de desaparecer sin
/// explicación).
class SelectorModoVenta extends StatelessWidget {
  const SelectorModoVenta({
    super.key,
    required this.modosDisponibles,
    required this.seleccionado,
    required this.onCambio,
  });

  /// Texto que explica por qué "Por medida" está apagado.
  static const avisoMedidaInactiva =
      'Para vender por peso, volumen o longitud, activa una medida en '
      'Configuración → Catálogo → Medidas.';

  final List<ModoVenta> modosDisponibles;
  final ModoVenta? seleccionado;
  final ValueChanged<ModoVenta> onCambio;

  static String etiqueta(ModoVenta modo) => switch (modo) {
    ModoVenta.presentacion => 'Lo cuento',
    ModoVenta.medida => 'Lo peso',
  };

  static String descripcion(ModoVenta modo) => switch (modo) {
    ModoVenta.presentacion => 'Se cuentan unidades, pares, botellas…',
    ModoVenta.medida => 'Se vende por kilos, litros, metros… al granel',
  };

  @override
  Widget build(BuildContext context) {
    if (modosDisponibles.isEmpty) {
      return Text(
        'No hay formas de venta activas en tu catálogo.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      );
    }

    final medidaApagada = !modosDisponibles.contains(ModoVenta.medida);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '¿Lo cuentas o lo pesas?',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SegmentedButton<ModoVenta>(
          segments: [
            for (final modo in modosDisponibles)
              ButtonSegment<ModoVenta>(
                value: modo,
                label: Text(etiqueta(modo)),
                tooltip: descripcion(modo),
              ),
            if (medidaApagada)
              ButtonSegment<ModoVenta>(
                value: ModoVenta.medida,
                label: Text(etiqueta(ModoVenta.medida)),
                tooltip: avisoMedidaInactiva,
                enabled: false,
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
        if (medidaApagada) ...[
          const SizedBox(height: 6),
          Text(
            avisoMedidaInactiva,
            key: const Key('aviso-medida-inactiva'),
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
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
