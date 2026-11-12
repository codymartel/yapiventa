import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/textos_dia_caja.dart';
import '../../application/services/textos_entrega_caja.dart';
import '../../domain/models/opciones_caja.dart';
import '../providers/venta_caja_provider.dart';
import 'chip_caja.dart';
import 'piezas_caja.dart';

/// Cómo se entrega y cómo se paga la venta. Las formas de pago y las zonas
/// son las que configuró CADA negocio (no hay una lista fija); la palabra de
/// cada entrega cambia con el rubro. Con delivery aparecen la zona (con su
/// costo) y «Cobrar al entregar».
class EntregaPagoCaja extends StatelessWidget {
  const EntregaPagoCaja({
    super.key,
    required this.provider,
    required this.rubro,
  });

  final VentaCajaProvider provider;
  final String rubro;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TituloSeccionCaja('Entrega'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in EntregaCaja.values)
              ChipCaja(
                etiqueta: TextosEntregaCaja.etiqueta(e, rubro: rubro),
                activo: p.entrega == e,
                altoMinimo: 44,
                onTap: () => p.elegirEntrega(e),
              ),
          ],
        ),
        if (p.esDelivery) ...[
          const SizedBox(height: 12),
          const TituloSeccionCaja('Zona'),
          const SizedBox(height: 6),
          if (p.zonas.isEmpty)
            const AvisoCaja(
              'Aún no tienes zonas de delivery. Agrégalas en Negocio '
              'para vender con delivery.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final z in p.zonas)
                  ChipCaja(
                    etiqueta:
                        '${z.nombre} · '
                        '${TextosDiaCaja.numero(z.costoCentavos)}',
                    activo: p.zona?.nombre == z.nombre,
                    altoMinimo: 44,
                    onTap: () => p.elegirZona(z),
                  ),
              ],
            ),
        ],
        const SizedBox(height: 12),
        const TituloSeccionCaja('Forma de pago'),
        const SizedBox(height: 6),
        if (p.opcionesPago.isEmpty)
          const AvisoCaja(
            'Aún no tienes formas de pago activas. Actívalas en '
            'Configuración para poder cobrar.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in p.opcionesPago)
                ChipCaja(
                  etiqueta: o.etiqueta,
                  activo: p.pago?.id == o.id,
                  altoMinimo: 44,
                  onTap: () => p.elegirPago(o),
                ),
            ],
          ),
        if (p.esDelivery)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Cobrar al entregar',
              style: TextStyle(color: AppColors.texto, fontSize: 14),
            ),
            subtitle: const Text(
              'El pago queda pendiente hasta entregar',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            value: p.cobrarAlEntregar,
            onChanged: p.cobrarAlEntregarActivo,
          ),
      ],
    );
  }
}
