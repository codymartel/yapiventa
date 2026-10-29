import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/familia_unidad.dart';
import '../../providers/formulario_medida_controller.dart';
import 'aviso_amarillo.dart';
import 'formato_entradas.dart';
import 'selector_por_medida.dart';
import 'vista_previa_medida_producto.dart';

/// Sección "Por medida": qué se mide, el precio y la cantidad que cubre, el
/// stock, la regla de venta y la vista previa del cliente. La unidad no se
/// elige: es la habitual del negocio. El estado vive en [FormularioMedidaController]; acá solo se
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
    this.conModelos = false,
  });

  final FormularioMedidaController medida;
  final bool stockInfinito;
  final String etiquetaGuardada;
  final ValueChanged<bool> onStockInfinitoCambiado;

  /// Con modelos el precio y el stock se escriben en cada modelo: acá solo
  /// quedan qué se mide, cuánto cubre cada precio y la regla de venta.
  final bool conModelos;

  @override
  Widget build(BuildContext context) {
    final familia = medida.familia;
    final unidad = medida.unidad;
    final familias = <FamiliaUnidad, String>{
      for (final activa in medida.medidasActivas())
        if (activa.familia != null) activa.familia!: activa.nombre,
    };
    final stock = medida.stock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (medida.familiaDesactivada)
          _FamiliaFija(medida: medida)
        else
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
        if (familia != null && unidad.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Tu unidad habitual es $unidad (se cambia en '
            'Configuración → Medidas).',
            key: const Key('unidad-habitual'),
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 10),
        SelectorPorMedida(medida: medida, conPrecio: !conModelos),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Stock infinito', style: TextStyle(fontSize: 13)),
          value: stockInfinito,
          onChanged: onStockInfinitoCambiado,
        ),
        if (!stockInfinito && !conModelos)
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
        if (!conModelos) VistaPreviaMedidaProducto(medida: medida),
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
        errorText:
            controller.text.trim().isNotEmpty && (valor == null || valor <= 0)
            ? 'Debe ser mayor que 0'
            : null,
      ),
    );
  }
}

/// La medida del producto, fija: el negocio la desactivó después, pero el
/// producto la conserva y no se cambia solo.
class _FamiliaFija extends StatelessWidget {
  const _FamiliaFija({required this.medida});

  final FormularioMedidaController medida;

  @override
  Widget build(BuildContext context) {
    final nombre = medida.medidaDelNegocio?.nombre ?? 'esta medida';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          key: const Key('medida-fija'),
          decoration: const InputDecoration(
            labelText: 'Qué mides',
            suffixIcon: Icon(Icons.lock_outline, size: 18),
          ),
          child: Text(nombre, style: TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(height: 8),
        AvisoAmarillo(
          key: const Key('aviso-medida-desactivada'),
          mensaje:
              'Desactivaste «$nombre» en Configuración → Medidas. Este '
              'producto sigue vendiéndose así; puedes cambiar nombre, precio '
              'y stock. Para cambiar la unidad o la regla, vuelve a activarla.',
        ),
      ],
    );
  }
}
