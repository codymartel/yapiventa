import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import '../../../application/services/sugerencias_modelos.dart';
import '../../providers/formulario_modelos_controller.dart';
import 'fila_modelo_producto.dart';
import 'foto_modelo.dart';

/// Los modelos del producto: cada uno con su foto y, debajo, las filas donde
/// se escribe el precio y el stock. El modelo NO tiene stock propio: su total
/// se suma solo (candado). La palabra del título la puso el vendedor.
class ListaModelosProducto extends StatelessWidget {
  const ListaModelosProducto({
    super.key,
    required this.modelos,
    required this.porMedida,
    required this.stockInfinito,
    required this.habilitada,
    required this.formatos,
    required this.referencia,
    required this.unidad,
    required this.factorStock,
    required this.unidadBase,
  });

  final FormularioModelosController modelos;
  final bool porMedida;
  final bool stockInfinito;
  final bool habilitada;

  /// Formatos de la presentación elegida (para elegir el tamaño de cada fila).
  final List<FormatoPresentacion> formatos;

  /// Por medida: lo que cubre cada precio ("¼ kg") y la unidad del stock.
  final String referencia;
  final String unidad;
  final int factorStock;
  final String unidadBase;

  static const _otraPalabra = '__otra__';

  Future<void> _pedirPalabra(BuildContext context) async {
    final controlador = TextEditingController();
    final palabra = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Cómo lo llamas?'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Talla, Número, Medida…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(controlador.text.trim()),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (palabra != null && palabra.isNotEmpty) {
      modelos.cambiarTituloFilas(palabra);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palabra = modelos.tituloCtrl.text.trim();
    final titulo = palabra.isEmpty ? 'Modelos' : palabra;
    return Container(
      key: const Key('lista-modelos'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeMedio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'una foto cada uno · sin stock propio',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          if (!porMedida) _selectorTitulo(context),
          for (final modelo in modelos.modelos)
            _TarjetaModelo(
              key: Key('modelo-${modelo.id}'),
              lista: this,
              modelo: modelo,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('agregar-modelo'),
              onPressed: habilitada && modelos.puedeAgregarModelo
                  ? () => modelos.agregarModelo(porMedida: porMedida)
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Agregar ${palabra.isEmpty ? 'modelo' : palabra.toLowerCase()}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorTitulo(BuildContext context) {
    final opciones = {
      ...SugerenciasModelos.titulosFilas,
      modelos.tituloFilas,
    }.toList();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Título de las filas:',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            key: ValueKey('titulo-filas-${modelos.tituloFilas}'),
            value: modelos.tituloFilas,
            underline: const SizedBox.shrink(),
            items: [
              for (final opcion in opciones)
                DropdownMenuItem(value: opcion, child: Text(opcion)),
              const DropdownMenuItem(
                value: _otraPalabra,
                child: Text('Otra palabra…'),
              ),
            ],
            onChanged: (valor) {
              if (valor == null) return;
              if (valor == _otraPalabra) {
                _pedirPalabra(context);
              } else {
                modelos.cambiarTituloFilas(valor);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TarjetaModelo extends StatelessWidget {
  const _TarjetaModelo({super.key, required this.lista, required this.modelo});

  final ListaModelosProducto lista;
  final ModeloEditable modelo;

  @override
  Widget build(BuildContext context) {
    final modelos = lista.modelos;
    final palabra = modelos.tituloCtrl.text.trim().toLowerCase();
    final tituloFilas = modelos.tituloFilas;
    final total = modelos.totalDelModelo(
      modelo,
      porMedida: lista.porMedida,
      factorStock: lista.factorStock,
      unidadBase: lista.unidadBase,
    );
    final aviso = lista.porMedida ? '' : modelos.avisoRepetido(modelo);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.bordeSutil)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FotoModelo(
            fotoNuevaBytes: modelo.fotoNuevaBytes,
            urlImagen: modelo.urlImagen,
            habilitada: lista.habilitada,
            onFotoElegida: (archivo, bytes) =>
                modelos.elegirFoto(modelo.id, archivo, bytes),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('nombre-modelo-${modelo.id}'),
                        controller: modelo.nombreCtrl,
                        onChanged: (_) => modelos.trasCambioTexto(),
                        style: TextStyle(color: AppColors.texto),
                        decoration: InputDecoration(
                          labelText:
                              'Nombre del ${palabra.isEmpty ? 'modelo' : palabra} *',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('quitar-modelo-${modelo.id}'),
                      tooltip: 'Quitar',
                      onPressed: lista.habilitada
                          ? () => modelos.quitarModelo(modelo.id)
                          : null,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                if (!lista.stockInfinito)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Total ',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          lista.porMedida && lista.unidad.isNotEmpty
                              ? '$total ${lista.unidad}'
                              : total,
                          key: Key('total-modelo-${modelo.id}'),
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            lista.porMedida
                                ? '(se suma solo)'
                                : '· el stock se escribe en cada ${tituloFilas.toLowerCase()}',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (lista.porMedida)
                  for (final fila in modelo.filas.take(1))
                    FilaModeloMedida(
                      modelos: modelos,
                      fila: fila,
                      referencia: lista.referencia,
                      unidad: lista.unidad,
                      conStock: !lista.stockInfinito,
                    )
                else
                  for (final fila in modelo.filas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: FilaModeloProducto(
                        modelos: modelos,
                        modelo: modelo,
                        fila: fila,
                        tituloFilas: tituloFilas,
                        formatos: lista.formatos,
                        conStock: !lista.stockInfinito,
                      ),
                    ),
                if (aviso.isNotEmpty)
                  Text(
                    aviso,
                    key: Key('aviso-repetido-${modelo.id}'),
                    style: TextStyle(color: AppColors.aviso, fontSize: 13),
                  ),
                if (!lista.porMedida)
                  Wrap(
                    children: [
                      TextButton.icon(
                        key: Key('agregar-fila-${modelo.id}'),
                        onPressed:
                            lista.habilitada && modelos.puedeAgregarFila(modelo)
                            ? () => modelos.agregarFila(modelo.id)
                            : null,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Agregar ${tituloFilas.toLowerCase()}'),
                      ),
                      if (modelo.filas.length > 1)
                        TextButton(
                          key: Key('mismo-precio-${modelo.id}'),
                          onPressed: lista.habilitada
                              ? () => modelos.mismoPrecio(modelo.id)
                              : null,
                          child: const Text('Mismo precio a todas'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
