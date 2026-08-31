import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/metodo_pago_tipo.dart';
import '../../domain/models/config_pago_metodo.dart';
import '../providers/configuracion_negocio_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// PasoPagos — Paso 4 del wizard: "Métodos de pago" (todos opcionales)
// ═════════════════════════════════════════════════════════════════════════

class PasoPagos extends StatelessWidget {
  const PasoPagos({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Métodos de pago (opcional)',
            style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Selecciona los que aceptarás.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 16),

        for (var i = 0; i < p.metodosPagoConfig.length; i++)
          _MetodoPagoCard(index: i, config: p.metodosPagoConfig[i]),

        if (p.errorValidacion != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Text(p.errorValidacion!, style: TextStyle(color: AppColors.error)),
          ),
        ],
      ],
    );
  }
}

class _MetodoPagoCard extends StatelessWidget {
  final int index;
  final ConfigPagoMetodo config;

  const _MetodoPagoCard({required this.index, required this.config});

  @override
  Widget build(BuildContext context) {
    final p = context.read<ConfiguracionNegocioProvider>();
    final tipo = MetodoPagoTipo.porId(config.metodoId);
    if (tipo == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: config.activo ? AppColors.blueLt.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(tipo.icono, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(tipo.nombre,
                      style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w600)),
                ],
              ),
              Switch(
                value: config.activo,
                onChanged: (v) =>
                    p.actualizarMetodoPago(index, (c) => c.copyWith(activo: v)),
              ),
            ],
          ),
          if (config.activo) ...[
            const SizedBox(height: 12),
            if (tipo.permiteNumeroPersonalizado)
              TextField(
                onChanged: (v) => p.actualizarMetodoPago(
                    index, (c) => c.copyWith(numeroPago: v)),
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  labelText: 'Número de ${tipo.nombre} (9 dígitos)',
                  filled: true,
                  fillColor: AppColors.fondo,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            if (tipo.permiteDescuento) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('¿Descuento por pagar con ${tipo.nombre}?',
                    style: TextStyle(color: AppColors.texto, fontSize: 13)),
                value: config.descuentoActivo,
                onChanged: (v) => p.actualizarMetodoPago(
                    index, (c) => c.copyWith(descuentoActivo: v)),
              ),
              if (config.descuentoActivo) ...[
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('% Porcentaje'),
                      selected: config.tipoDescuento == TipoDescuento.porcentaje,
                      onSelected: (_) => p.actualizarMetodoPago(
                          index, (c) => c.copyWith(tipoDescuento: TipoDescuento.porcentaje)),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('S/ Monto fijo'),
                      selected: config.tipoDescuento == TipoDescuento.montoFijo,
                      onSelected: (_) => p.actualizarMetodoPago(
                          index, (c) => c.copyWith(tipoDescuento: TipoDescuento.montoFijo)),
                    ),
                  ],
                ),
                TextField(
                  onChanged: (v) => p.actualizarMetodoPago(
                      index, (c) => c.copyWith(valorDescuento: v)),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.texto),
                  decoration: InputDecoration(
                    labelText: config.tipoDescuento == TipoDescuento.porcentaje
                        ? 'Valor del descuento (%)'
                        : 'Valor del descuento (S/)',
                    filled: true,
                    fillColor: AppColors.fondo,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                TextField(
                  onChanged: (v) => p.actualizarMetodoPago(
                      index, (c) => c.copyWith(montoMinimo: v)),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.texto),
                  decoration: InputDecoration(
                    labelText: 'Monto mínimo para el descuento',
                    filled: true,
                    fillColor: AppColors.fondo,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}