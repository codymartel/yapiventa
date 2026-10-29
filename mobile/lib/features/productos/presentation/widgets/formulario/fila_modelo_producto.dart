import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import '../../../domain/models/familia_unidad.dart';
import '../../../domain/models/formato_elegido.dart';
import '../../providers/formulario_modelos_controller.dart';
import 'formato_entradas.dart';

/// Una fila "Se vende en" de un modelo por presentación: talla / formato,
/// precio y stock. Con formatos de botella (500 ml, 1.5 L) la etiqueta se
/// ELIGE de la lista, así la fila guarda el tamaño real; si no, se escribe.
/// En pantallas angostas los campos se apilan en dos líneas.
class FilaModeloProducto extends StatelessWidget {
  const FilaModeloProducto({
    super.key,
    required this.modelos,
    required this.modelo,
    required this.fila,
    required this.tituloFilas,
    required this.formatos,
    required this.conStock,
  });

  final FormularioModelosController modelos;
  final ModeloEditable modelo;
  final FilaEditable fila;
  final String tituloFilas;

  /// Formatos de la presentación elegida; con 2 o más se muestra una lista.
  final List<FormatoPresentacion> formatos;
  final bool conStock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restriccion) {
        final angosta = restriccion.maxWidth < 330;
        final etiqueta = _etiqueta();
        final precio = _precio();
        final stock = conStock ? _stock() : null;
        final quitar = IconButton(
          key: Key('quitar-fila-${fila.id}'),
          tooltip: 'Quitar fila',
          onPressed: () => modelos.quitarFila(modelo.id, fila.id),
          icon: Icon(Icons.close, size: 18, color: AppColors.muted),
        );

        if (angosta) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: etiqueta),
                  quitar,
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: precio),
                  if (stock != null) ...[
                    const SizedBox(width: 8),
                    Expanded(child: stock),
                  ],
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: etiqueta),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: precio),
            if (stock != null) ...[
              const SizedBox(width: 8),
              Expanded(flex: 2, child: stock),
            ],
            quitar,
          ],
        );
      },
    );
  }

  /// Cómo se lee un formato en la lista: «de 30 unidades», «de 500 ml».
  static String textoFormato(FormatoPresentacion formato) {
    final esUnidad =
        formato.familia == FamiliaUnidad.conteo &&
        formato.unidadVisible.nombre == 'unidad';
    if (!esUnidad) return 'de ${formato.etiqueta}';
    final n = formato.valorBase;
    return 'de $n ${n == 1 ? 'unidad' : 'unidades'}';
  }

  Widget _etiqueta() {
    if (formatos.length > 1) {
      final actual = fila.etiquetaCtrl.text;
      return DropdownButtonFormField<String>(
        key: Key('etiqueta-${fila.id}-$actual'),
        initialValue: formatos.any((f) => f.etiqueta == actual) ? actual : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: tituloFilas, isDense: true),
        items: [
          for (final formato in formatos)
            DropdownMenuItem(
              value: formato.etiqueta,
              child: Text(textoFormato(formato)),
            ),
        ],
        onChanged: (valor) {
          if (valor == null) return;
          final elegido = formatos.firstWhere((f) => f.etiqueta == valor);
          modelos.elegirFormato(
            fila,
            valor,
            FormatoElegido(
              valorBase: elegido.valorBase,
              familia: elegido.familia.name,
              unidad: elegido.unidadVisible.nombre,
            ),
          );
        },
      );
    }
    return TextField(
      key: Key('etiqueta-${fila.id}'),
      controller: fila.etiquetaCtrl,
      onChanged: (_) => modelos.trasCambioTexto(),
      style: TextStyle(color: AppColors.texto),
      decoration: InputDecoration(labelText: tituloFilas, isDense: true),
    );
  }

  Widget _precio() => TextField(
    key: Key('precio-${fila.id}'),
    controller: fila.precioCtrl,
    onChanged: (_) => modelos.trasCambioTexto(),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: const [FormatoPrecio()],
    style: TextStyle(color: AppColors.texto),
    decoration: const InputDecoration(labelText: 'Precio S/', isDense: true),
  );

  Widget _stock() => TextField(
    key: Key('stock-${fila.id}'),
    controller: fila.stockCtrl,
    onChanged: (_) => modelos.trasCambioTexto(),
    keyboardType: TextInputType.number,
    inputFormatters: const [FormatoEntero()],
    style: TextStyle(color: AppColors.texto),
    decoration: const InputDecoration(labelText: 'Stock', isDense: true),
  );
}

/// La única fila de un modelo por medida (queso fresco, queso andino): su
/// precio por la cantidad de referencia del producto y su stock en la unidad
/// del producto, con decimales.
class FilaModeloMedida extends StatelessWidget {
  const FilaModeloMedida({
    super.key,
    required this.modelos,
    required this.fila,
    required this.referencia,
    required this.unidad,
    required this.conStock,
  });

  final FormularioModelosController modelos;
  final FilaEditable fila;

  /// "¼ kg": lo que cubre el precio.
  final String referencia;
  final String unidad;
  final bool conStock;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: Key('precio-${fila.id}'),
            controller: fila.precioCtrl,
            onChanged: (_) => modelos.trasCambioTexto(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoPrecio()],
            style: TextStyle(color: AppColors.texto),
            decoration: InputDecoration(
              labelText: referencia.isEmpty
                  ? 'Precio S/'
                  : 'Precio S/ por $referencia',
              isDense: true,
            ),
          ),
        ),
        if (conStock) ...[
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('stock-${fila.id}'),
              controller: fila.stockCtrl,
              onChanged: (_) => modelos.trasCambioTexto(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [FormatoCantidad()],
              style: TextStyle(color: AppColors.texto),
              decoration: InputDecoration(
                labelText: 'Stock',
                suffixText: unidad.isEmpty ? null : unidad,
                isDense: true,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
