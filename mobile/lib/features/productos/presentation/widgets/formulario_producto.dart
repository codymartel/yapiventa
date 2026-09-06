import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../domain/models/producto.dart';
import '../providers/productos_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioProducto
// ═════════════════════════════════════════════════════════════════════════
// Migración de tu @Composable FormularioProducto. Diálogo para crear o
// editar un producto. La foto se sube directo a Cloudinary (vía la
// interfaz SubidorDeImagenes) y solo entonces se llama a
// productosProvider.guardarProducto() — mismo orden que tu Kotlin
// (sube primero, guarda con la URL después).
//
// unidadesDisponibles llega como List<Map<String,dynamic>> porque así
// se guardó en Firestore desde ConfiguracionNegocioProvider (nombre,
// tipo, fraccionesPermitidas, esOpcional) — no se reconstruye como
// UnidadInfo aquí, para no duplicar lógica de conversión.
// ═════════════════════════════════════════════════════════════════════════

class FormularioProducto extends StatefulWidget {
  final Producto? producto;
  final List<String> categoriasDisponibles;
  final List<Map<String, dynamic>> unidadesDisponibles;
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
  late final _nombreCtrl = TextEditingController(text: widget.producto?.nombre ?? '');
  late final _precioCtrl = TextEditingController(
    text: (widget.producto?.precio ?? 0) > 0 ? widget.producto!.precio.toString() : '',
  );
  late final _stockCtrl = TextEditingController(
    text: (widget.producto?.stock ?? 0) > 0 ? widget.producto!.stock.toString() : '',
  );
  late final _descripcionCtrl = TextEditingController(text: widget.producto?.descripcion ?? '');

  late bool _esStockInfinito = widget.producto?.esStockInfinito ?? false;
  late bool _tieneDelivery = widget.producto?.tieneDelivery ?? true;
  late String _categoria = widget.producto?.categoria ??
      (widget.categoriasDisponibles.isNotEmpty ? widget.categoriasDisponibles.first : '');
  late String _unidad = widget.producto?.unidadMedidaNombre ?? '';
  late String _fraccion = widget.producto?.fraccionesSeleccionadas.firstOrNull ?? '';
  String _urlImagenActual = '';
  XFile? _fotoNueva;
  bool _subiendo = false;

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

  Map<String, dynamic>? get _unidadActual =>
      widget.unidadesDisponibles.cast<Map<String, dynamic>?>().firstWhere(
            (u) => u?['nombre'] == _unidad,
            orElse: () => null,
          );

  List<String> get _fraccionesPermitidas =>
      (_unidadActual?['fraccionesPermitidas'] as List?)?.cast<String>() ?? [];

  bool get _esFraccionaria => _unidadActual?['tipo'] == 'fraccionaria';

  bool get _precioValido => (double.tryParse(_precioCtrl.text) ?? 0) > 0;
  bool get _stockValido => _esStockInfinito || (int.tryParse(_stockCtrl.text) ?? 0) > 0;
  bool get _fraccionValida => !_esFraccionaria || _fraccion.isNotBlank;
  bool get _camposOk =>
      _nombreCtrl.text.isNotBlank &&
      _precioValido &&
      _stockValido &&
      _categoria.isNotBlank &&
      _unidad.isNotBlank &&
      _fraccionValida &&
      !_subiendo;

  Future<void> _elegirFoto() async {
    final picker = ImagePicker();
    final archivo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (archivo != null) setState(() => _fotoNueva = archivo);
  }

  Future<void> _guardar() async {
    if (!_camposOk) return;

    setState(() => _subiendo = true);

    var urlFinal = _urlImagenActual;
    if (_fotoNueva != null) {
      final provider = context.read<ProductosProvider>();
      final bytes = await _fotoNueva!.readAsBytes();
      try {
        final resultado = await CloudinaryService().subir(
          bytes: bytes,
          carpeta: 'usuarios/${provider.uid}/productos',
          nombreArchivo: _fotoNueva!.name,
        );
        urlFinal = resultado.url;
      } catch (e) {
        if (mounted) {
          setState(() => _subiendo = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error al subir la foto: $e')));
        }
        return;
      }
    }

    if (!mounted) return;
    final nuevo = Producto(
      id: widget.producto?.id ?? '',
      negocioId: '', // el provider lo fuerza al uid actual, no hace falta ponerlo bien aquí
      nombre: _nombreCtrl.text.trim(),
      precio: double.tryParse(_precioCtrl.text) ?? 0,
      stock: _esStockInfinito ? 9999 : (int.tryParse(_stockCtrl.text) ?? 0),
      esStockInfinito: _esStockInfinito,
      descripcion: _descripcionCtrl.text.trim(),
      categoria: _categoria,
      tieneDelivery: _tieneDelivery,
      urlImagen: urlFinal,
      unidadMedidaNombre: _unidad,
      fraccionesSeleccionadas: _fraccion.isNotBlank ? [_fraccion] : [],
    );

    final exito = await context.read<ProductosProvider>().guardarProducto(nuevo);
    setState(() => _subiendo = false);
    if (exito && mounted) widget.onCancelar(); // cierra el diálogo
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      title: Text(
        widget.producto == null ? 'Agregar producto' : 'Editar producto',
        style: TextStyle(color: AppColors.texto),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── FOTO ──────────────────────────────────
              GestureDetector(
                onTap: _subiendo ? null : _elegirFoto,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _fotoNueva != null
                      ? Image.network(_fotoNueva!.path, fit: BoxFit.cover) // web usa blob path
                      : (_urlImagenActual.isNotEmpty
                          ? Image.network(_urlImagenActual, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                'Foto del producto (opcional)\ntoca para elegir',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted, fontSize: 12),
                              ),
                            )),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _nombreCtrl,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: AppColors.texto),
                decoration: const InputDecoration(labelText: 'Nombre del producto *'),
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
                title: const Text('Stock infinito', style: TextStyle(fontSize: 13)),
                value: _esStockInfinito,
                onChanged: (v) => setState(() => _esStockInfinito = v),
              ),
              if (!_esStockInfinito)
                TextField(
                  controller: _stockCtrl,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.texto),
                  decoration: const InputDecoration(labelText: 'Cantidad en stock *'),
                ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                initialValue: _categoria.isNotBlank ? _categoria : null,
                decoration: const InputDecoration(labelText: 'Categoría *'),
                items: widget.categoriasDisponibles
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v ?? ''),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                initialValue: _unidad.isNotBlank ? _unidad : null,
                decoration: const InputDecoration(labelText: 'Unidad de medida *'),
                items: widget.unidadesDisponibles
                    .map((u) => DropdownMenuItem(
                          value: u['nombre'] as String,
                          child: Text(u['nombre'] as String),
                        ))
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
                  decoration: const InputDecoration(labelText: 'Fracción *'),
                  items: _fraccionesPermitidas
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
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
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
              ),
              const SizedBox(height: 10),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tiene delivery', style: TextStyle(fontSize: 13)),
                value: _tieneDelivery,
                onChanged: (v) => setState(() => _tieneDelivery = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _subiendo ? null : widget.onCancelar,
          child: Text('Cancelar', style: TextStyle(color: AppColors.muted)),
        ),
        ElevatedButton(
          onPressed: _camposOk ? _guardar : null,
          child: _subiendo
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar producto'),
        ),
      ],
    );
  }
}

extension on String {
  bool get isNotBlank => trim().isNotEmpty;
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}