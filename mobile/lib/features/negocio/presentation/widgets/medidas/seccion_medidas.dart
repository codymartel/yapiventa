import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../productos/domain/models/familia_unidad.dart';
import '../../providers/configuracion_negocio_provider.dart';

import 'editor_medida.dart';
import 'tarjeta_medida.dart';

// ═════════════════════════════════════════════════════════════════════════
// SeccionMedidas — pestaña "Medidas" del paso Catálogo
// ═════════════════════════════════════════════════════════════════════════
//
// La interfaz "Venta por medida": tarjetas de las medidas del rubro (peso,
// volumen, longitud, área) y su editor. Muestra por medida: nombre, familia
// protegida, unidad base protegida, unidad habitual, mínimo, incremento,
// cantidades rápidas, venta por cantidad, venta por soles y activa/inactiva.
//
// REGLAS heredadas del dominio (ConfiguracionMedida):
//   - Los valores se escriben SIEMPRE en la unidad base (g, ml, mm, cm²).
//   - La unidad habitual se elige de un dropdown filtrado a la familia
//     (nunca texto libre): Peso g/kg, Volumen ml/L, Longitud mm/cm/m,
//     Área cm²/m².
//   - Las cantidades rápidas son enteros con unidad + botones 1/4, 1/2,
//     3/4 y 1 de la unidad de referencia.
//   - No se usan double: las etiquetas salen por FormateadorPresentacion
//     (250 g → 1/4 kg, 1500 ml → 1 1/2 L, 600 ml → 600 ml).
//   - El editor valida antes de guardar con los mismos criterios (y
//     mensajes) que el provider: mínimo>0, incremento>0, rápidas fieles a
//     mínimo+incremento, sin duplicados, unidad de la familia, y al menos
//     venta por cantidad o por monto.
//
// NO calcula precios, NO toca Productos ni la web.
// ═════════════════════════════════════════════════════════════════════════

class SeccionMedidas extends StatelessWidget {
  const SeccionMedidas({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    final medidas = p.medidas;
    final activas = medidas.where((medida) => medida.activa).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CabeceraMedidas(cantidadActivas: activas),
        const SizedBox(height: 16),
        if (medidas.isEmpty)
          const Text(
            'Aún no hay medidas configuradas para este rubro.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          )
        else
          for (final medida in medidas) ...[
            TarjetaMedida(
              medida: medida,
              onEditar:
                  medida.requiereRevision ||
                      medida.familia == null ||
                      medida.unidadVisual == null
                  ? null
                  : () => _abrirEditorMedida(context, medida.familia!),
              onCambiarActiva:
                  medida.requiereRevision ||
                      medida.obligatoria ||
                      medida.familia == null
                  ? null
                  : (activa) =>
                        p.establecerMedidaActiva(medida.familia!, activa: activa),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _CabeceraMedidas extends StatelessWidget {
  final int cantidadActivas;

  const _CabeceraMedidas({required this.cantidadActivas});

  @override
  Widget build(BuildContext context) {
    final titulo = const Text(
      'Venta por medida',
      style: TextStyle(
        color: AppColors.texto,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
    final descripcion = const Text(
      'Define cómo se vende por peso, volumen, longitud o área: '
      'mínimo, incremento y cantidades rápidas desde la unidad base.',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: AppColors.muted, fontSize: 13),
    );
    final contador = Text(
      '$cantidadActivas activas',
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titulo, const SizedBox(height: 4), descripcion],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [contador],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titulo,
            const SizedBox(height: 4),
            descripcion,
            const SizedBox(height: 12),
            contador,
          ],
        );
      },
    );
  }
}

Future<void> _abrirEditorMedida(BuildContext context, FamiliaUnidad familia) {
  context.read<ConfiguracionNegocioProvider>().limpiarErrorCatalogo();
  return showDialog<void>(
    context: context,
    builder: (_) => EditorMedida(familia: familia),
  );
}
