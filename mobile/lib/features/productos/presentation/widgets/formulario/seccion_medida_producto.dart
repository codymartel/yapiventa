import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../../domain/models/familia_unidad.dart';
import '../../providers/formulario_medida_controller.dart';
import 'aviso_amarillo.dart';
import 'formato_entradas.dart';
import 'vista_previa_medida_producto.dart';

/// Sección "Por medida": qué se mide, la unidad, el precio (por 1 unidad o
/// por otra cantidad), el stock, la regla de venta y la vista previa del
/// cliente. El estado vive en [FormularioMedidaController]; acá solo se
/// pinta.
///
/// El mínimo y el incremento nunca bloquean el stock (regla de producto).
class SeccionMedidaProducto extends StatelessWidget {
  const SeccionMedidaProducto({
    super.key,
    required this.medida,
    required this.stockInfinito,
    required this.etiquetaGuardada,
    required this.onStockInfinitoCambiado,
  });

  final FormularioMedidaController medida;
  final bool stockInfinito;
  final String etiquetaGuardada;
  final ValueChanged<bool> onStockInfinitoCambiado;

  @override
  Widget build(BuildContext context) {
    final familia = medida.familia;
    final unidad = medida.unidad;
    final unidades = familia == null
        ? const <UnidadRegistrada>[]
        : RegistroUnidades.unidadesDe(familia);
    final familias = <FamiliaUnidad, String>{
      for (final activa in medida.medidasActivas())
        if (activa.familia != null) activa.familia!: activa.nombre,
    };
    final referencia = medida.referencia;
    final stock = medida.stock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<FamiliaUnidad>(
          key: ValueKey('medida-${familia?.name ?? ''}'),
          initialValue: familia,
          decoration: const InputDecoration(labelText: 'Qué mides *'),
          items: [
            for (final entrada in familias.entries)
              DropdownMenuItem<FamiliaUnidad>(
                value: entrada.key,
                child: Text(entrada.value),
              ),
          ],
          onChanged: (valor) {
            if (valor != null) medida.cambiarFamilia(valor);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('unidad-${familia?.name ?? ''}-$unidad'),
          initialValue: unidad.isNotEmpty ? unidad : null,
          decoration: const InputDecoration(labelText: 'Unidad de venta *'),
          items: [
            for (final opcion in unidades)
              DropdownMenuItem<String>(
                value: opcion.nombre,
                child: Text(opcion.nombre),
              ),
          ],
          onChanged: (valor) {
            if (valor != null) medida.cambiarUnidad(valor);
          },
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('precio-medida'),
                controller: medida.precioCtrl,
                onChanged: (_) => medida.trasCambioTexto(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [FormatoPrecio()],
                style: TextStyle(color: AppColors.texto),
                decoration: const InputDecoration(labelText: 'Precio S/ *'),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<bool>(
                key: ValueKey('precio-por-$unidad-${medida.precioPorUnidad}'),
                initialValue: medida.precioPorUnidad,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Precio'),
                items: [
                  DropdownMenuItem(
                    value: true,
                    child: Text(unidad.isEmpty ? 'por unidad' : 'por $unidad'),
                  ),
                  const DropdownMenuItem(
                    value: false,
                    child: Text('por otra cantidad'),
                  ),
                ],
                onChanged: (valor) {
                  if (valor != null) medida.cambiarPrecioPorUnidad(valor);
                },
              ),
            ),
          ],
        ),
        if (!medida.precioPorUnidad) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('referencia-medida'),
            controller: medida.referenciaCtrl,
            onChanged: (_) => medida.trasCambioTexto(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoCantidad()],
            style: TextStyle(color: AppColors.texto),
            decoration: InputDecoration(
              labelText: 'Cantidad que cubre el precio *',
              suffixText: unidad.isEmpty ? null : unidad,
              errorText: medida.referenciaCtrl.text.trim().isEmpty
                  ? null
                  : referencia?.error,
            ),
          ),
          if (medida.resumenPrecio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              medida.resumenPrecio,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
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
            key: const Key('stock-medida'),
            controller: medida.stockCtrl,
            onChanged: (_) => medida.trasCambioTexto(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoCantidad()],
            style: TextStyle(color: AppColors.texto),
            decoration: InputDecoration(
              labelText: 'Stock *',
              suffixText: unidad.isEmpty ? null : unidad,
              errorText: stock?.error,
            ),
          ),
        const SizedBox(height: 10),
        _ReglaDeVenta(medida: medida),
        const SizedBox(height: 10),
        VistaPreviaMedidaProducto(medida: medida),
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

/// Regla de venta: la de la medida del negocio o una propia del producto.
class _ReglaDeVenta extends StatelessWidget {
  const _ReglaDeVenta({required this.medida});

  final FormularioMedidaController medida;

  @override
  Widget build(BuildContext context) {
    final delNegocio = medida.medidaDelNegocio;
    final base = medida.unidadBaseNombre;
    final reglaNegocio = delNegocio == null
        ? 'Regla del negocio'
        : 'Regla del negocio: desde ${delNegocio.minimoBase} $base, '
              'de ${delNegocio.incrementoBase} en ${delNegocio.incrementoBase} '
              '$base';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('switch-regla-propia'),
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Mínimo e incremento propios',
            style: TextStyle(fontSize: 13),
          ),
          subtitle: medida.reglaPropia
              ? null
              : Text(
                  reglaNegocio,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
          value: medida.reglaPropia,
          onChanged: medida.cambiarReglaPropia,
        ),
        if (medida.reglaPropia)
          Row(
            children: [
              Expanded(
                child: _CampoEntero(
                  clave: 'minimo-propio',
                  controller: medida.minimoCtrl,
                  etiqueta: 'Desde *',
                  sufijo: base,
                  onCambio: medida.trasCambioTexto,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CampoEntero(
                  clave: 'incremento-propio',
                  controller: medida.incrementoCtrl,
                  etiqueta: 'De cuánto en cuánto *',
                  sufijo: base,
                  onCambio: medida.trasCambioTexto,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CampoEntero extends StatelessWidget {
  const _CampoEntero({
    required this.clave,
    required this.controller,
    required this.etiqueta,
    required this.sufijo,
    required this.onCambio,
  });

  final String clave;
  final TextEditingController controller;
  final String etiqueta;
  final String sufijo;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final valor = int.tryParse(controller.text.trim());
    return TextField(
      key: Key(clave),
      controller: controller,
      onChanged: (_) => onCambio(),
      keyboardType: TextInputType.number,
      inputFormatters: const [FormatoEntero()],
      style: TextStyle(color: AppColors.texto),
      decoration: InputDecoration(
        labelText: etiqueta,
        suffixText: sufijo.isEmpty ? null : sufijo,
        errorText: controller.text.trim().isNotEmpty &&
                (valor == null || valor <= 0)
            ? 'Debe ser mayor que 0'
            : null,
      ),
    );
  }
}
