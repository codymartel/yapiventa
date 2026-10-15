import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../../domain/models/catalogo_venta/formateador_presentacion.dart';

import 'nombre_familia_medida.dart';

// Tarjeta de una medida del catálogo (peso, volumen, longitud, área).

class TarjetaMedida extends StatelessWidget {
  final MedidaVentaPersistida medida;
  final VoidCallback? onEditar;

  /// Activa o desactiva la medida desde la tarjeta. null deja el switch
  /// fijo (medida obligatoria o pendiente de revisión).
  final ValueChanged<bool>? onCambiarActiva;

  const TarjetaMedida({
    super.key,
    required this.medida,
    this.onEditar,
    this.onCambiarActiva,
  });

  @override
  Widget build(BuildContext context) {
    final familia = medida.familia;
    final base = medida.unidadBase;
    final visual = medida.unidadVisual;
    final familiaLegible = familia == null ? '—' : nombreFamiliaMedida(familia);
    final baseLegible = base?.nombre ?? '—';
    final visualLegible = visual?.nombre ?? '—';

    final rapidaEtiquetas = (familia != null && visual != null)
        ? medida.cantidadesRapidasBase
              .map(
                (valor) => FormateadorPresentacion.formatear(
                  FormateadorPresentacion.cantidadEnFamilia(familia, valor),
                  visual,
                ),
              )
              .join(', ')
        : null;

    final minimo = (base != null && medida.minimoBase > 0)
        ? '${medida.minimoBase} ${base.nombre}'
        : '—';
    final incremento = (base != null && medida.incrementoBase > 0)
        ? '${medida.incrementoBase} ${base.nombre}'
        : '—';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Material(
        key: Key('medida-card-${familia?.name ?? medida.id}'),
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      medida.nombre,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch(
                    key: Key(
                      'switch-tarjeta-medida-${familia?.name ?? medida.id}',
                    ),
                    value: medida.activa,
                    onChanged: onCambiarActiva,
                  ),
                ],
              ),
              if (medida.obligatoria)
                const _LineaTarjeta('Obligatoria: siempre activa.')
              else if (medida.requiereRevision)
                const _LineaTarjeta(
                  'Revisa esta medida para poder activarla.',
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _EstadoMedida(activa: medida.activa),
                  if (medida.requiereRevision)
                    const _EtiquetaChipMedida(
                      texto: 'Requiere revisión',
                      color: AppColors.error,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _LineaTarjeta('Familia: $familiaLegible'),
              _LineaTarjeta(
                'Unidad base: $baseLegible  ·  Unidad habitual: '
                '$visualLegible',
              ),
              _LineaTarjeta('Mínimo: $minimo  ·  Incremento: $incremento'),
              _LineaTarjeta('Cantidades rápidas: ${rapidaEtiquetas ?? '—'}'),
              _LineaTarjeta(
                'Por cantidad: ${medida.permiteCantidad ? 'Sí' : 'No'}  ·  '
                'Por soles: ${medida.permiteMonto ? 'Sí' : 'No'}',
              ),
              if (onEditar != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: Key('editar-medida-${familia?.name ?? medida.id}'),
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LineaTarjeta extends StatelessWidget {
  final String texto;

  const _LineaTarjeta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        texto,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }
}

class _EstadoMedida extends StatelessWidget {
  final bool activa;

  const _EstadoMedida({required this.activa});

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.blueLt : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(
          activa ? 'Activa' : 'Inactiva',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EtiquetaChipMedida extends StatelessWidget {
  final String texto;
  final Color color;

  const _EtiquetaChipMedida({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
