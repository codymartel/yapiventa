import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import 'aviso_amarillo.dart';
import 'formato_entradas.dart';

/// Formato de presentación elegido en el formulario.
class FormatoElegido {
  const FormatoElegido({
    required this.valorBase,
    required this.familia,
    required this.unidad,
  });

  final int valorBase;

  /// Nombre de la familia ('peso', 'volumen'…) tal como se persiste.
  final String familia;

  /// Nombre de la unidad visible ('ml', 'kg'…).
  final String unidad;
}

/// Sección "Por presentación": presentación activa, su formato, el precio
/// por presentación y el stock en unidades enteras.
///
/// El estado vive en el formulario; acá solo se pinta y se notifica. La
/// presentación guardada que ya no está activa se muestra igual (con aviso
/// amarillo no bloqueante) para que la persona sepa qué había antes.
class SeccionPresentacionProducto extends StatelessWidget {
  const SeccionPresentacionProducto({
    super.key,
    required this.presentaciones,
    required this.presentacionId,
    required this.formatoEtiqueta,
    required this.precioController,
    required this.stockController,
    required this.stockInfinito,
    required this.etiquetaGuardada,
    required this.onPresentacionCambiada,
    required this.onFormatoCambiado,
    required this.onStockInfinitoCambiado,
    required this.onCambioTexto,
  });

  final List<OpcionPresentacion> presentaciones;
  final String presentacionId;
  final String formatoEtiqueta;
  final TextEditingController precioController;
  final TextEditingController stockController;
  final bool stockInfinito;
  final String etiquetaGuardada;
  final ValueChanged<String> onPresentacionCambiada;
  final ValueChanged<FormatoElegido> onFormatoCambiado;
  final ValueChanged<bool> onStockInfinitoCambiado;

  /// Se llama cada vez que cambia un texto: el formulario recalcula si el
  /// bot�n Guardar debe estar habilitado.
  final VoidCallback onCambioTexto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('presentacion-$presentacionId'),
          initialValue: presentacionId.isNotEmpty ? presentacionId : null,
          decoration: const InputDecoration(labelText: 'Presentación *'),
          items: [
            for (final presentacion in presentaciones)
              DropdownMenuItem<String>(
                value: presentacion.id,
                child: Text(presentacion.nombre),
              ),
          ],
          onChanged: (valor) {
            if (valor != null) onPresentacionCambiada(valor);
          },
        ),
        const SizedBox(height: 10),
        _FormatosPresentacion(
          presentaciones: presentaciones,
          presentacionId: presentacionId,
          formatoEtiqueta: formatoEtiqueta,
          onFormatoCambiado: onFormatoCambiado,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: precioController,
          onChanged: (_) => onCambioTexto(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [FormatoPrecio()],
          style: TextStyle(color: AppColors.texto),
          decoration: const InputDecoration(
            labelText: 'Precio por presentación S/ *',
          ),
        ),
        const SizedBox(height: 6),
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
            keyboardType: TextInputType.number,
            inputFormatters: const [FormatoEntero()],
            style: TextStyle(color: AppColors.texto),
            decoration: const InputDecoration(
              labelText: 'Cantidad en stock *',
            ),
          ),
        if (etiquetaGuardada.isNotEmpty) ...[
          const SizedBox(height: 10),
          AvisoAmarillo(
            mensaje:
                'Este producto usa una unidad propia («$etiquetaGuardada»). '
                'Puedes guardar sin cambios o elegir una presentación del '
                'catálogo para que la tienda web la muestre mejor.',
          ),
        ],
      ],
    );
  }
}

/// Dropdown de formatos de la presentación elegida. Con un solo formato se
/// autoselecciona y solo se muestra como texto.
class _FormatosPresentacion extends StatelessWidget {
  const _FormatosPresentacion({
    required this.presentaciones,
    required this.presentacionId,
    required this.formatoEtiqueta,
    required this.onFormatoCambiado,
  });

  final List<OpcionPresentacion> presentaciones;
  final String presentacionId;
  final String formatoEtiqueta;
  final ValueChanged<FormatoElegido> onFormatoCambiado;

  @override
  Widget build(BuildContext context) {
    if (presentacionId.isEmpty) return const SizedBox.shrink();
    final coincidencias = presentaciones
        .where((presentacion) => presentacion.id == presentacionId)
        .toList();
    if (coincidencias.isEmpty) return const SizedBox.shrink();
    final formatos = coincidencias.first.formatos;
    if (formatos.isEmpty) return const SizedBox.shrink();
    if (formatos.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          'Formato: ${formatos.first.etiqueta}',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      key: const ValueKey('formato'),
      initialValue: formatoEtiqueta.isNotEmpty ? formatoEtiqueta : null,
      decoration: const InputDecoration(labelText: 'Formato *'),
      items: [
        for (final formato in formatos)
          DropdownMenuItem<String>(
            value: formato.etiqueta,
            child: Text(formato.etiqueta),
          ),
      ],
      onChanged: (etiqueta) {
        if (etiqueta == null) return;
        final formato = formatos.firstWhere(
          (formato) => formato.etiqueta == etiqueta,
        );
        onFormatoCambiado(
          FormatoElegido(
            valorBase: formato.valorBase,
            familia: formato.familia.name,
            unidad: formato.unidadVisible.nombre,
          ),
        );
      },
    );
  }
}
