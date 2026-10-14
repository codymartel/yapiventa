import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../../domain/models/familia_unidad.dart';
import 'aviso_amarillo.dart';
import 'formato_entradas.dart';

/// Sección "Por medida": familia activa, unidad visual, el precio y la
/// cantidad de referencia que cubre, y el stock en la unidad visual con
/// decimales (se convierte a gramos/ml enteros).
///
/// El mínimo y el incremento del catálogo se muestran como INFORMACIÓN:
/// nunca bloquean el stock (regla de producto).
class SeccionMedidaProducto extends StatelessWidget {
  const SeccionMedidaProducto({
    super.key,
    required this.medidasActivas,
    required this.familia,
    required this.unidadVisual,
    required this.precioController,
    required this.referenciaController,
    required this.stockController,
    required this.stockInfinito,
    required this.resumenPrecio,
    required this.errorReferencia,
    required this.errorStock,
    required this.etiquetaGuardada,
    required this.onFamiliaCambiada,
    required this.onUnidadCambiada,
    required this.onStockInfinitoCambiado,
    required this.onCambioTexto,
  });

  final List<MedidaVentaPersistida> medidasActivas;
  final FamiliaUnidad? familia;
  final String unidadVisual;
  final TextEditingController precioController;
  final TextEditingController referenciaController;
  final TextEditingController stockController;
  final bool stockInfinito;
  final String resumenPrecio;
  final String? errorReferencia;
  final String? errorStock;
  final String etiquetaGuardada;
  final ValueChanged<FamiliaUnidad> onFamiliaCambiada;
  final ValueChanged<String> onUnidadCambiada;
  final ValueChanged<bool> onStockInfinitoCambiado;

  /// Se llama cada vez que cambia un texto: el formulario recalcula si el
  /// bot�n Guardar debe estar habilitado.
  final VoidCallback onCambioTexto;

  MedidaVentaPersistida? get _medidaActiva {
    if (familia == null) return null;
    final coincidencias = medidasActivas
        .where((medida) => medida.familia == familia)
        .toList();
    return coincidencias.isEmpty ? null : coincidencias.first;
  }

  List<UnidadRegistrada> get _unidadesDeFamilia =>
      familia == null ? const [] : RegistroUnidades.unidadesDe(familia!);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<FamiliaUnidad>(
          key: ValueKey('medida-${familia?.name ?? ''}'),
          initialValue: familia,
          decoration: const InputDecoration(labelText: 'Qué mides *'),
          items: [
            for (final medida in medidasActivas)
              if (medida.familia != null)
                DropdownMenuItem<FamiliaUnidad>(
                  value: medida.familia,
                  child: Text(medida.nombre),
                ),
          ],
          onChanged: (valor) {
            if (valor != null) onFamiliaCambiada(valor);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('unidad-${familia?.name ?? ''}-$unidadVisual'),
          initialValue: unidadVisual.isNotEmpty ? unidadVisual : null,
          decoration: const InputDecoration(labelText: 'Unidad *'),
          items: [
            for (final unidad in _unidadesDeFamilia)
              DropdownMenuItem<String>(
                value: unidad.nombre,
                child: Text(unidad.nombre),
              ),
          ],
          onChanged: (valor) {
            if (valor != null) onUnidadCambiada(valor);
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: precioController,
          onChanged: (_) => onCambioTexto(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [FormatoPrecio()],
          style: TextStyle(color: AppColors.texto),
          decoration: const InputDecoration(labelText: 'Precio S/ *'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: referenciaController,
          onChanged: (_) => onCambioTexto(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [FormatoCantidad()],
          style: TextStyle(color: AppColors.texto),
          decoration: InputDecoration(
            labelText: '¿Desde cuánto? (en $unidadVisual) *',
            errorText: errorReferencia,
          ),
        ),
        if (resumenPrecio.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            resumenPrecio,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Stock infinito', style: TextStyle(fontSize: 13)),
          value: stockInfinito,
          onChanged: onStockInfinitoCambiado,
        ),
        if (!stockInfinito)
          TextField(
            controller: stockController,
            onChanged: (_) => onCambioTexto(),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: const [FormatoCantidad()],
            style: TextStyle(color: AppColors.texto),
            decoration: InputDecoration(
              labelText: 'Cantidad en stock (en $unidadVisual) *',
              errorText: errorStock,
            ),
          ),
        const SizedBox(height: 10),
        _InfoReglaMedida(medida: _medidaActiva, familia: familia),
        if (etiquetaGuardada.isNotEmpty) ...[
          const SizedBox(height: 10),
          AvisoAmarillo(
            mensaje:
                'Este producto usa una unidad propia («$etiquetaGuardada»). '
                'Completa la medida para migrarlo, o guarda sin cambios y '
                'se queda como está.',
          ),
        ],
      ],
    );
  }
}

/// Mínimo, incremento y modalidades de la medida: solo informativa.
class _InfoReglaMedida extends StatelessWidget {
  const _InfoReglaMedida({required this.medida, required this.familia});

  final MedidaVentaPersistida? medida;
  final FamiliaUnidad? familia;

  @override
  Widget build(BuildContext context) {
    if (medida == null || familia == null) {
      return const SizedBox.shrink();
    }
    final base = RegistroUnidades.baseDe(familia!);
    String cantidad(int valor) => '$valor ${base.nombre}';

    final lineas = <String>[
      'Mínimo: ${cantidad(medida!.minimoBase)}',
      'Incremento: ${cantidad(medida!.incrementoBase)}',
    ];
    if (medida!.permiteMonto) {
      lineas.add('Podés vender por monto');
    }
    if (medida!.permiteCantidad) {
      lineas.add('Podés vender por cantidad');
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bordeSutil),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Regla de esta medida (informativa)',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (final linea in lineas)
            Text(
              linea,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
