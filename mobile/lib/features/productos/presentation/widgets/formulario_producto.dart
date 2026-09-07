import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/tipo_unidad.dart';
import '../../domain/models/producto.dart';
import '../providers/productos_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioProducto
// ═════════════════════════════════════════════════════════════════════════
// Migración de tu @Composable FormularioProducto. Diálogo para crear o
// editar un producto. El formulario entrega los datos y los bytes al
// provider; la coordinación entre imagen y persistencia vive fuera de UI.
//
// Las unidades ya llegan tipadas desde el catálogo del negocio. El widget
// no conoce el formato usado para persistirlas en Firestore.
// ═════════════════════════════════════════════════════════════════════════

class FormularioProducto extends StatefulWidget {
  final Producto? producto;
  final List<String> categoriasDisponibles;
  final List<UnidadInfo> unidadesDisponibles;
  final VoidCallback onCancelar;

  const FormularioProducto({
    super.key,
    this.producto,
    required this.categoriasDisponibles,
    required this.unidadesDisponibles,
    required this.onCancelar,
  });

  @override
  State<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  late final _nombreCtrl = TextEditingController(
    text: widget.producto?.nombre ?? '',
  );
  late final _precioCtrl = TextEditingController(
    text: (widget.producto?.precio ?? 0) > 0
        ? widget.producto!.precio.toString()
        : '',
  );
  late final _stockCtrl = TextEditingController(
    text: (widget.producto?.stock ?? 0) > 0
        ? widget.producto!.stock.toString()
        : '',
  );
  late final _descripcionCtrl = TextEditingController(
    text: widget.producto?.descripcion ?? '',
  );

  late bool _esStockInfinito = widget.producto?.esStockInfinito ?? false;
  late bool _tieneDelivery = widget.producto?.tieneDelivery ?? true;
  late String _categoria =
      widget.producto?.categoria ??
      (widget.categoriasDisponibles.isNotEmpty
          ? widget.categoriasDisponibles.first
          : '');
  late String _unidad = widget.producto?.unidadMedidaNombre ?? '';
  late String _fraccion =
      widget.producto?.fraccionesSeleccionadas.firstOrNull ?? '';
  String _urlImagenActual = '';
  XFile? _fotoNueva;
  Uint8List? _fotoNuevaBytes;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _urlImagenActual = widget.producto?.urlImagen ?? '';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _stockCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  List<String> get _categoriasEfectivas {
    final categorias = <String>{...widget.categoriasDisponibles};
    final categoriaGuardada = widget.producto?.categoria ?? '';
    if (categoriaGuardada.isNotBlank) categorias.add(categoriaGuardada);
    return categorias.toList();
  }

  List<UnidadInfo> get _unidadesEfectivas {
    final unidades = <String, UnidadInfo>{
      for (final unidad in widget.unidadesDisponibles) unidad.nombre: unidad,
    };
    final nombreGuardado = widget.producto?.unidadMedidaNombre ?? '';
    if (nombreGuardado.isNotBlank && !unidades.containsKey(nombreGuardado)) {
      final fracciones = widget.producto?.fraccionesSeleccionadas ?? const [];
      unidades[nombreGuardado] = UnidadInfo(
        nombre: nombreGuardado,
        tipo: fracciones.isEmpty ? TipoUnidad.entera : TipoUnidad.fraccionaria,
        fraccionesPermitidas: fracciones,
      );
    }
    return unidades.values.toList();
  }

  UnidadInfo? get _unidadActual => _unidadesEfectivas
      .cast<UnidadInfo?>()
      .firstWhere((u) => u?.nombre == _unidad, orElse: () => null);

  List<String> get _fraccionesPermitidas {
    final fracciones = <String>{...?_unidadActual?.fraccionesPermitidas};
    if (_fraccion.isNotBlank) fracciones.add(_fraccion);
    return fracciones.toList();
  }

  bool get _esFraccionaria => _unidadActual?.tipo == TipoUnidad.fraccionaria;

  bool get _precioValido => (double.tryParse(_precioCtrl.text) ?? 0) > 0;
  bool get _stockValido =>
      _esStockInfinito || (int.tryParse(_stockCtrl.text) ?? 0) > 0;
  bool get _fraccionValida => !_esFraccionaria || _fraccion.isNotBlank;
  bool get _camposOk =>
      _nombreCtrl.text.isNotBlank &&
      _precioValido &&
      _stockValido &&
      _categoria.isNotBlank &&
      _unidad.isNotBlank &&
      _fraccionValida &&
      !_guardando;

  Future<void> _elegirFoto() async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (archivo == null) return;

      final bytes = await archivo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _fotoNueva = archivo;
        _fotoNuevaBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo leer la foto: $e')));
    }
  }

  Future<void> _guardar() async {
    if (!_camposOk || _guardando) return;

    setState(() => _guardando = true);
    final nuevo = Producto(
      id: widget.producto?.id ?? '',
      negocioId: widget.producto?.negocioId ?? '',
      nombre: _nombreCtrl.text.trim(),
      precio: double.tryParse(_precioCtrl.text) ?? 0,
      stock: _esStockInfinito ? 9999 : (int.tryParse(_stockCtrl.text) ?? 0),
      esStockInfinito: _esStockInfinito,
      descripcion: _descripcionCtrl.text.trim(),
      categoria: _categoria,
      disponible: widget.producto?.disponible ?? true,
      tieneDelivery: _tieneDelivery,
      urlImagen: _urlImagenActual,
      cloudinaryPublicId: widget.producto?.cloudinaryPublicId,
      unidadMedidaNombre: _unidad,
      fraccionesSeleccionadas: _fraccion.isNotBlank ? [_fraccion] : [],
      fechaVencimiento: widget.producto?.fechaVencimiento,
    );

    final provider = context.read<ProductosProvider>();
    final exito = widget.producto == null
        ? await provider.crearProducto(
            nuevo,
            imagenBytes: _fotoNuevaBytes,
            nombreArchivo: _fotoNueva?.name,
          )
        : await provider.guardarProducto(
            nuevo,
            imagenBytes: _fotoNuevaBytes,
            nombreArchivo: _fotoNueva?.name,
          );

    if (!mounted) return;
    setState(() => _guardando = false);
    final messenger = ScaffoldMessenger.of(context);
    if (exito) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.producto == null
                ? 'Producto creado correctamente.'
                : 'Producto actualizado correctamente.',
          ),
        ),
      );
      widget.onCancelar();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'No se pudo guardar el producto.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text(
          widget.producto == null ? 'Agregar producto' : 'Editar producto',
          style: TextStyle(color: AppColors.texto),
        ),
        content: SizedBox(
          width: 420,
          child: AbsorbPointer(
            absorbing: _guardando,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── FOTO ──────────────────────────────────
                  GestureDetector(
                    onTap: _guardando ? null : _elegirFoto,
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _fotoNuevaBytes != null
                          ? Image.memory(_fotoNuevaBytes!, fit: BoxFit.cover)
                          : (_urlImagenActual.isNotEmpty
                                ? Image.network(
                                    _urlImagenActual,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      'Foto del producto (opcional)\ntoca para elegir',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _nombreCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: AppColors.texto),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _precioCtrl,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.texto),
                    decoration: const InputDecoration(labelText: 'Precio S/ *'),
                  ),
                  const SizedBox(height: 10),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Stock infinito',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _esStockInfinito,
                    onChanged: (v) => setState(() => _esStockInfinito = v),
                  ),
                  if (!_esStockInfinito)
                    TextField(
                      controller: _stockCtrl,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.texto),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad en stock *',
                      ),
                    ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: _categoria.isNotBlank ? _categoria : null,
                    decoration: const InputDecoration(labelText: 'Categoría *'),
                    items: _categoriasEfectivas
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoria = v ?? ''),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: _unidad.isNotBlank ? _unidad : null,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de medida *',
                    ),
                    items: _unidadesEfectivas
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.nombre,
                            child: Text(u.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _unidad = v ?? '';
                      _fraccion = '';
                    }),
                  ),
                  if (_esFraccionaria && _fraccionesPermitidas.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _fraccion.isNotBlank ? _fraccion : null,
                      decoration: const InputDecoration(
                        labelText: 'Fracción *',
                      ),
                      items: _fraccionesPermitidas
                          .map(
                            (f) => DropdownMenuItem(value: f, child: Text(f)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _fraccion = v ?? ''),
                    ),
                  ],
                  const SizedBox(height: 10),

                  TextField(
                    controller: _descripcionCtrl,
                    style: TextStyle(color: AppColors.texto),
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                    ),
                  ),
                  const SizedBox(height: 10),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tiene delivery',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _tieneDelivery,
                    onChanged: (v) => setState(() => _tieneDelivery = v),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _guardando ? null : widget.onCancelar,
            child: Text('Cancelar', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: _camposOk ? _guardar : null,
            child: _guardando
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Guardando...'),
                    ],
                  )
                : const Text('Guardar producto'),
          ),
        ],
      ),
    );
  }
}

extension on String {
  bool get isNotBlank => trim().isNotEmpty;
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
