import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../application/services/entrada_numerica.dart';
import '../../../domain/models/estructura_producto.dart';
import '../../../domain/models/producto.dart';
import '../../providers/formulario_combo_controller.dart';
import 'hoja_o_dialogo.dart';
import 'miniatura_parte.dart';

/// Elige los productos de un combo: hoja desde abajo en celular, diálogo en
/// PC. Cada producto con su cantidad; con variables, cada modelo y fila es una
/// línea («Polo · Azul · M»). «Agregar» las suma al combo.
Future<void> abrirSelectorPartes(
  BuildContext context,
  FormularioComboController combo,
) {
  return abrirHojaODialogo(
    context,
    construir: (contexto) => _ContenidoSelector(
      combo: combo,
      onCerrar: () => Navigator.of(contexto).pop(),
    ),
  );
}

class _Opcion {
  const _Opcion({
    required this.parte,
    required this.precioCentavos,
    required this.stock,
  });

  /// La parte con cantidad 1; el selector le pone la cantidad elegida.
  final ParteCombo parte;
  final int precioCentavos;

  /// null = stock infinito.
  final int? stock;
}

/// Una línea por producto, o por cada modelo y fila si tiene variables.
List<_Opcion> _opciones(List<Producto> productos) {
  final opciones = <_Opcion>[];
  for (final producto in productos) {
    if (!producto.tieneModelos) {
      opciones.add(
        _Opcion(
          parte: ParteCombo(
            productoId: producto.id,
            cantidad: 1,
            nombre: producto.nombre,
            urlImagen: producto.urlImagen,
          ),
          precioCentavos: producto.precioCentavos,
          stock: producto.esStockInfinito ? null : producto.stock,
        ),
      );
      continue;
    }
    for (final modelo in producto.modelos) {
      for (final fila in modelo.filas) {
        final etiqueta = fila.etiqueta.isEmpty ? '' : ' · ${fila.etiqueta}';
        opciones.add(
          _Opcion(
            parte: ParteCombo(
              productoId: producto.id,
              modeloId: modelo.id,
              filaId: fila.id,
              cantidad: 1,
              nombre: '${producto.nombre} · ${modelo.nombre}$etiqueta',
              urlImagen: modelo.urlImagen.isNotEmpty
                  ? modelo.urlImagen
                  : producto.urlImagen,
            ),
            precioCentavos: fila.precioCentavos,
            stock: producto.esStockInfinito ? null : fila.stock,
          ),
        );
      }
    }
  }
  return opciones;
}

class _ContenidoSelector extends StatefulWidget {
  const _ContenidoSelector({required this.combo, required this.onCerrar});

  final FormularioComboController combo;
  final VoidCallback onCerrar;

  @override
  State<_ContenidoSelector> createState() => _ContenidoSelectorState();
}

class _ContenidoSelectorState extends State<_ContenidoSelector> {
  late final List<_Opcion> _lista = _opciones(widget.combo.elegibles);
  final Map<String, int> _cantidades = {};

  int get _distintas => _cantidades.values.where((c) => c > 0).length;

  /// Cuántas líneas nuevas entrarían al combo (las que ya están solo suman).
  int get _nuevas {
    final existentes = widget.combo.partes.map((p) => p.clave).toSet();
    return _cantidades.entries
        .where((e) => e.value > 0 && !existentes.contains(e.key))
        .length;
  }

  bool get _cabe => widget.combo.partes.length + _nuevas <= ParteCombo.maximo;

  void _cambiar(String clave, int delta) {
    setState(() {
      final nueva = (_cantidades[clave] ?? 0) + delta;
      if (nueva < 0) return;
      _cantidades[clave] = nueva;
    });
  }

  void _agregar() {
    for (final opcion in _lista) {
      final cantidad = _cantidades[opcion.parte.clave] ?? 0;
      if (cantidad > 0) {
        widget.combo.agregar(opcion.parte.conCantidad(cantidad));
      }
    }
    widget.onCerrar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Agregar al ${widget.combo.nombre.palabra}',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Solo productos que se cuentan, sin combos dentro de combos. '
          'Máximo ${ParteCombo.maximo} productos.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        if (_lista.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Todavía no tienes productos para agregar.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        // La lista se desplaza dentro de su propio espacio: los botones de
        // abajo se quedan a la vista aunque haya muchos productos.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final opcion in _lista)
                  _Linea(
                    opcion: opcion,
                    cantidad: _cantidades[opcion.parte.clave] ?? 0,
                    onCambiar: (delta) => _cambiar(opcion.parte.clave, delta),
                  ),
              ],
            ),
          ),
        ),
        if (!_cabe)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Revisa: un ${widget.combo.nombre.palabra} lleva como máximo '
              '${ParteCombo.maximo} productos.',
              key: const Key('aviso-maximo-partes'),
              style: TextStyle(
                color: AppColors.aviso,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const Key('cancelar-partes'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: widget.onCerrar,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                key: const Key('agregar-partes'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _distintas == 0 || !_cabe ? null : _agregar,
                child: const Text('Agregar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({
    required this.opcion,
    required this.cantidad,
    required this.onCambiar,
  });

  final _Opcion opcion;
  final int cantidad;
  final void Function(int delta) onCambiar;

  @override
  Widget build(BuildContext context) {
    final stock = opcion.stock == null ? 'ilimitado' : '${opcion.stock}';
    final clave = opcion.parte.clave;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.dim)),
      ),
      child: Row(
        children: [
          MiniaturaParte(url: opcion.parte.urlImagen),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opcion.parte.nombre,
                  style: TextStyle(color: AppColors.texto, fontSize: 14),
                ),
                Text(
                  'S/ ${centavosATexto(opcion.precioCentavos)} · stock $stock',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('menos-$clave'),
            tooltip: 'Quitar uno',
            onPressed: cantidad > 0 ? () => onCambiar(-1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$cantidad',
              key: Key('cantidad-$clave'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: Key('mas-$clave'),
            tooltip: 'Agregar uno',
            onPressed: () => onCambiar(1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
