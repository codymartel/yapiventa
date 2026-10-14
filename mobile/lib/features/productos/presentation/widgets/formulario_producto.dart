import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../../negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import '../../../negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import '../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/modo_venta.dart';
import '../../domain/models/producto.dart';
import '../providers/productos_provider.dart';
import 'formulario/medida_entrada.dart';
import 'formulario/seccion_medida_producto.dart';
import 'formulario/seccion_presentacion_producto.dart';
import 'formulario/selector_modo_venta.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioProducto
// ═════════════════════════════════════════════════════════════════════════
// Diálogo para crear o editar un producto, ahora conducido por el catálogo
// de venta del negocio (presentaciones y medidas activas).
//
// REGLAS DE PRODUCTO que implementa:
//   1. El selector de modo solo muestra los modos ACTIVOS del catálogo.
//   2. En medida, el stock se escribe en la unidad visual (kg, L…) con
//      decimales y se convierte a entero en unidad base (g, ml). El mínimo
//      y el incremento NUNCA bloquean: son informativos.
//   3. Un solo campo de precio por modo: precio por presentación, o precio
//      de la cantidad de referencia en medida.
//   4. Los productos legacy (sin presentacionId) NO están obligados a
//      migrar: se guardan Como Están, con un aviso amarillo que invita a
//      elegir una forma de venta. Migrar es obligatorio solo para productos
//      nuevos o cuando la persona completa la sección del modo elegido.
//   5. Si el catálogo de venta no cargó (o falló), el cuerpo muestra el
//      motivo y un botón Reintentar: el FAB de origen nunca queda mudo.
// ═════════════════════════════════════════════════════════════════════════

class FormularioProducto extends StatefulWidget {
  final Producto? producto;
  final List<String> categoriasDisponibles;

  /// Catálogo de venta del negocio (presentaciones y medidas activas).
  final CatalogoVentaPersistido? catalogoVenta;
  final bool cargandoVenta;
  final String? ventaErrorMessage;
  final Future<void> Function()? onReintentarVenta;

  final VoidCallback onCancelar;
  final VoidCallback? onGuardado;

  const FormularioProducto({
    super.key,
    this.producto,
    required this.categoriasDisponibles,
    required this.catalogoVenta,
    this.cargandoVenta = false,
    this.ventaErrorMessage,
    this.onReintentarVenta,
    required this.onCancelar,
    this.onGuardado,
  });

  @override
  State<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  late final _nombreCtrl = TextEditingController(
    text: widget.producto?.nombre ?? '',
  );
  late final _descripcionCtrl = TextEditingController(
    text: widget.producto?.descripcion ?? '',
  );
  late final _stockPresentacionCtrl = TextEditingController(
    text: (widget.producto?.stock ?? 0) > 0
        ? widget.producto!.stock.toString()
        : '',
  );
  late final _precioPresentacionCtrl = TextEditingController(
    text: (widget.producto?.precio ?? 0) > 0
        ? centavosATexto(widget.producto!.precioCentavos)
        : '',
  );
  late final _precioMedidaCtrl = TextEditingController(text: '');
  late final _referenciaCtrl = TextEditingController(text: '');
  late final _stockMedidaCtrl = TextEditingController(text: '');

  late bool _esStockInfinito = widget.producto?.esStockInfinito ?? false;
  late bool _tieneDelivery = widget.producto?.tieneDelivery ?? true;

  late String _categoria = '';

  ModoVenta? _modoVista;
  String _presentacionId = '';
  String _formatoEtiqueta = '';
  FormatoElegido? _formato;
  FamiliaUnidad? _medidaFamilia;
  String _medidaUnidad = '';

  String _urlImagenActual = '';
  XFile? _fotoNueva;
  Uint8List? _fotoNuevaBytes;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _urlImagenActual = widget.producto?.urlImagen ?? '';
    _precargarDesde(widget.producto);
  }

  /// Precarga el formulario desde el producto editado. Nunca migra datos:
  /// solo muestra lo que había y sugiere el modo cuando la etiqueta legacy
  /// es una unidad de medida (kg, L…).
  void _precargarDesde(Producto? producto) {
    // La categoría guardada manda; si está vacía se usa la primera
    // disponible (el ?? no sirve: '' no es null).
    final categoriaGuardada = producto?.categoria.trim() ?? '';
    _categoria = categoriaGuardada.isNotEmpty
        ? categoriaGuardada
        : (widget.categoriasDisponibles.isNotEmpty
              ? widget.categoriasDisponibles.first
              : '');

    if (producto == null) {
      _modoVista = _modosDisponibles.isEmpty ? null : _modosDisponibles.first;
      return;
    }

    if (producto.esPorMedida) {
      _modoVista = ModoVenta.medida;
      _medidaFamilia = producto.medidaFamilia;
      _medidaUnidad = producto.medidaUnidad;
      final factor = _factorDe(_medidaUnidad);
      if (producto.cantidadReferenciaBase > 0 && factor > 0) {
        _referenciaCtrl.text = baseATextoVisual(
          producto.cantidadReferenciaBase,
          factor,
        );
      }
      if (producto.precioCentavos > 0) {
        _precioMedidaCtrl.text = centavosATexto(producto.precioCentavos);
      }
      final stockBase = producto.stockBase;
      if (stockBase != null && stockBase > 0 && factor > 0) {
        _stockMedidaCtrl.text = baseATextoVisual(stockBase, factor);
      }
      return;
    }

    _modoVista = ModoVenta.presentacion;
    _presentacionId = producto.presentacionId;
    if (_presentacionId.isNotEmpty && producto.formatoValorBase > 0) {
      final etiqueta = _etiquetaFormatoGuardado(producto);
      _formatoEtiqueta = etiqueta ?? '';
      _formato = FormatoElegido(
        valorBase: producto.formatoValorBase,
        familia: producto.formatoFamilia?.name ?? '',
        unidad: producto.formatoUnidad,
      );
    }

    // Etiqueta legacy tipo kg/g/L/ml: se SUGIERE el modo medida, sin
    // migrar nada (los campos de medida quedan vacíos a propósito).
    if (_presentacionId.isEmpty && _esUnidadDeMedida(producto.etiquetaUnidad)) {
      _modoVista = ModoVenta.medida;
      _medidaUnidad = producto.etiquetaUnidad;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _stockPresentacionCtrl.dispose();
    _precioPresentacionCtrl.dispose();
    _precioMedidaCtrl.dispose();
    _referenciaCtrl.dispose();
    _stockMedidaCtrl.dispose();
    super.dispose();
  }

  // ── Catálogo ──────────────────────────────────────────────────────────

  List<OpcionPresentacion> get _presentacionesActivas => (widget
          .catalogoVenta
          ?.presentaciones ??
      const <OpcionPresentacion>[])
      .where((presentacion) => presentacion.activa)
      .toList();

  List<MedidaVentaPersistida> get _medidasActivas => (widget.catalogoVenta
          ?.medidas ??
      const <MedidaVentaPersistida>[])
      .where(
        (medida) => medida.activa && medida.familia != null,
      )
      .toList();

  List<ModoVenta> get _modosDisponibles {
    final modos = <ModoVenta>[];
    if (_presentacionesActivas.isNotEmpty) modos.add(ModoVenta.presentacion);
    if (_medidasActivas.isNotEmpty) modos.add(ModoVenta.medida);
    return modos;
  }

  int _factorDe(String unidadNombre) {
    if (unidadNombre.isEmpty) return 0;
    for (final familia in FamiliaUnidad.values) {
      for (final unidad in RegistroUnidades.unidadesDe(familia)) {
        if (unidad.nombre == unidadNombre) return unidad.factorBase;
      }
    }
    return 0;
  }

  String get _unidadBaseNombre =>
      _medidaFamilia == null ? '' : RegistroUnidades.baseDe(_medidaFamilia!).nombre;

  bool _esUnidadDeMedida(String nombre) {
    if (nombre.isEmpty) return false;
    for (final familia in FamiliaUnidad.values) {
      if (familia == FamiliaUnidad.conteo) continue;
      for (final unidad in RegistroUnidades.unidadesDe(familia)) {
        if (unidad.nombre.toLowerCase() == nombre.toLowerCase()) return true;
      }
    }
    return false;
  }

  String? _etiquetaFormatoGuardado(Producto producto) {
    final familia = producto.formatoFamilia;
    if (familia == null || producto.formatoValorBase <= 0) return null;
    final guardada = _presentacionesActivas
        .where((presentacion) => presentacion.id == _presentacionId)
        .expand((presentacion) => presentacion.formatos)
        .where(
          (formato) =>
              formato.valorBase == producto.formatoValorBase &&
              formato.familia == familia &&
              formato.unidadVisible.nombre == producto.formatoUnidad,
        )
        .toList();
    if (guardada.isNotEmpty) return guardada.first.etiqueta;
    try {
      final unidad = _unidadRegistrada(producto.formatoUnidad);
      if (unidad == null) return null;
      return FormatoPresentacion(
        valorBase: producto.formatoValorBase,
        familia: familia,
        unidadVisible: unidad,
      ).etiqueta;
    } catch (_) {
      return null;
    }
  }

  UnidadRegistrada? _unidadRegistrada(String nombre) {
    for (final familia in FamiliaUnidad.values) {
      for (final unidad in RegistroUnidades.unidadesDe(familia)) {
        if (unidad.nombre == nombre) return unidad;
      }
    }
    return null;
  }

  // ── Estado derivado ───────────────────────────────────────────────────

  bool get _presentacionCompleta {
    if (_presentacionId.isEmpty || _formato == null) return false;
    final presentaciones = _presentacionesActivas.where(
      (presentacion) => presentacion.id == _presentacionId,
    );
    if (presentaciones.isEmpty) return false;
    final formato = _formato!;
    return presentaciones.first.formatos.any(
      (candidato) =>
          candidato.valorBase == formato.valorBase &&
          candidato.familia.name == formato.familia &&
          candidato.unidadVisible.nombre == formato.unidad,
    );
  }

  ConversionCantidad? get _referencia => _convertir(_referenciaCtrl.text);

  ConversionCantidad? get _stockMedida => _convertir(_stockMedidaCtrl.text);

  ConversionCantidad? _convertir(String texto) {
    if (texto.trim().isEmpty) return null;
    final factor = _factorDe(_medidaUnidad);
    if (factor <= 0) return null;
    return textoAUnidadBase(texto, factor, unidadBase: _unidadBaseNombre);
  }

  bool get _medidaCompleta {
    if (_medidaFamilia == null || _medidaUnidad.isEmpty) return false;
    final referencia = _referencia;
    if (referencia == null || !referencia.esValida) return false;
    final centavos = textoACentavos(_precioMedidaCtrl.text);
    if (centavos == null || centavos <= 0) return false;
    if (_esStockInfinito) return true;
    final stock = _stockMedida;
    return stock != null && stock.esValida;
  }

  String get _resumenPrecioMedida {
    final factor = _factorDe(_medidaUnidad);
    final centavos = textoACentavos(_precioMedidaCtrl.text);
    final referencia = _referencia;
    if (factor <= 0 || centavos == null || centavos <= 0) return '';
    if (referencia == null || !referencia.esValida) return '';
    return 'S/ ${centavosATexto(centavos)} por '
        '${baseATextoVisual(referencia.base!, factor)} $_medidaUnidad';
  }

  int? get _precioVisibleCentavos {
    if (_modoVista == ModoVenta.medida) {
      return textoACentavos(_precioMedidaCtrl.text);
    }
    return textoACentavos(_precioPresentacionCtrl.text);
  }

  bool get _stockPresentacionValido =>
      _esStockInfinito ||
      (int.tryParse(_stockPresentacionCtrl.text) ?? -1) >= 0;

  /// Lo visible en la vista de medida es coherente: lo escrito, si hay algo
  /// escrito, convierte. Un valor inválido (ej. una cantidad que truncada
  /// da cero) bloquea aunque el producto sea legacy: "rechazar con mensaje".
  /// Los campos vacíos, en cambio, permiten guardar sin migrar.
  bool get _medidaVistaValida {
    if (_precioMedidaCtrl.text.trim().isNotEmpty) {
      final centavos = textoACentavos(_precioMedidaCtrl.text);
      if (centavos == null || centavos <= 0) return false;
    }
    if (_referenciaCtrl.text.trim().isNotEmpty) {
      final referencia = _referencia;
      if (referencia == null || !referencia.esValida) return false;
    }
    if (!_esStockInfinito && _stockMedidaCtrl.text.trim().isNotEmpty) {
      final stock = _stockMedida;
      if (stock == null || !stock.esValida) return false;
    }
    return true;
  }

  bool get _camposOk {
    if (_guardando) return false;
    if (_nombreCtrl.text.trim().isEmpty) return false;
    if (_categoria.isEmpty) return false;

    final esNuevo = widget.producto == null;
    if (_modoVista == ModoVenta.medida) {
      if (!_medidaVistaValida) return false;
      if (_medidaCompleta) return true;
      // Legacy sin migrar: se puede guardar (regla 4).
      return !esNuevo;
    }

    final centavos = _precioVisibleCentavos;
    if (centavos == null || centavos <= 0) return false;
    if (!_stockPresentacionValido) return false;
    if (_presentacionCompleta) return true;
    // Legacy sin presentación: se puede guardar (regla 4).
    return !esNuevo;
  }

  // ── Acciones ──────────────────────────────────────────────────────────

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

  Producto _construirProducto() {
    final anterior = widget.producto;
    final comun =
        (
          id: anterior?.id ?? '',
          negocioId: anterior?.negocioId ?? '',
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          categoria: _categoria,
          disponible: anterior?.disponible ?? true,
          tieneDelivery: _tieneDelivery,
          urlImagen: _urlImagenActual,
          cloudinaryPublicId: anterior?.cloudinaryPublicId,
          fechaVencimiento: anterior?.fechaVencimiento,
          esStockInfinito: _esStockInfinito,
        );

    if (_modoVista == ModoVenta.medida && _medidaCompleta) {
      return Producto(
        id: comun.id,
        negocioId: comun.negocioId,
        nombre: comun.nombre,
        descripcion: comun.descripcion,
        categoria: comun.categoria,
        disponible: comun.disponible,
        tieneDelivery: comun.tieneDelivery,
        urlImagen: comun.urlImagen,
        cloudinaryPublicId: comun.cloudinaryPublicId,
        fechaVencimiento: comun.fechaVencimiento,
        esStockInfinito: _esStockInfinito,
        modoVenta: ModoVenta.medida,
        medidaFamilia: _medidaFamilia,
        medidaUnidad: _medidaUnidad,
        cantidadReferenciaBase: _referencia!.base!,
        precioCentavos: textoACentavos(_precioMedidaCtrl.text)!,
        stockBase: _esStockInfinito ? null : _stockMedida!.base!,
        stock: anterior?.stock ?? 0,
      );
    }

    if (_presentacionCompleta) {
      final formato = _formato!;
      return Producto(
        id: comun.id,
        negocioId: comun.negocioId,
        nombre: comun.nombre,
        descripcion: comun.descripcion,
        categoria: comun.categoria,
        disponible: comun.disponible,
        tieneDelivery: comun.tieneDelivery,
        urlImagen: comun.urlImagen,
        cloudinaryPublicId: comun.cloudinaryPublicId,
        fechaVencimiento: comun.fechaVencimiento,
        esStockInfinito: _esStockInfinito,
        modoVenta: ModoVenta.presentacion,
        presentacionId: _presentacionId,
        formatoValorBase: formato.valorBase,
        formatoFamilia: FamiliaUnidad.values.firstWhere(
          (familia) => familia.name == formato.familia,
        ),
        formatoUnidad: formato.unidad,
        precioCentavos: textoACentavos(_precioPresentacionCtrl.text)!,
        stock: int.tryParse(_stockPresentacionCtrl.text) ?? 0,
      );
    }

    // Sin migrar: se conserva la unidad propia y las fracciones leídas.
    return Producto(
      id: comun.id,
      negocioId: comun.negocioId,
      nombre: comun.nombre,
      descripcion: comun.descripcion,
      categoria: comun.categoria,
      disponible: comun.disponible,
      tieneDelivery: comun.tieneDelivery,
      urlImagen: comun.urlImagen,
      cloudinaryPublicId: comun.cloudinaryPublicId,
      fechaVencimiento: comun.fechaVencimiento,
      esStockInfinito: _esStockInfinito,
      modoVenta: ModoVenta.presentacion,
      presentacionId: anterior?.presentacionId ?? '',
      etiquetaUnidad: anterior?.etiquetaUnidad ?? '',
      precioCentavos:
          _precioVisibleCentavos ?? anterior?.precioCentavos ?? 0,
      stock: anterior?.stock ?? 0,
      fraccionesSeleccionadas:
          anterior?.fraccionesSeleccionadas ?? const [],
    );
  }

  Future<void> _guardar() async {
    if (!_camposOk) return;
    setState(() => _guardando = true);
    final nuevo = _construirProducto();

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
      widget.onGuardado?.call();
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

  void _trasCambioTexto() {
    setState(() {});
  }

  void _cambiarModo(ModoVenta modo) {
    setState(() => _modoVista = modo);
  }

  void _cambiarPresentacion(String id) {
    setState(() {
      _presentacionId = id;
      _formato = null;
      _formatoEtiqueta = '';
      final presentaciones = _presentacionesActivas.where(
        (presentacion) => presentacion.id == id,
      );
      if (presentaciones.isEmpty) return;
      final formatos = presentaciones.first.formatos;
      if (formatos.length == 1) {
        _formatoEtiqueta = formatos.first.etiqueta;
        _formato = FormatoElegido(
          valorBase: formatos.first.valorBase,
          familia: formatos.first.familia.name,
          unidad: formatos.first.unidadVisible.nombre,
        );
      }
    });
  }

  void _cambiarFamilia(FamiliaUnidad familia) {
    setState(() {
      _medidaFamilia = familia;
      final activas = _medidasActivas
          .where((medida) => medida.familia == familia)
          .toList();
      _medidaUnidad = activas.isEmpty
          ? ''
          : (activas.first.unidadVisual?.nombre ?? '');
    });
  }

  // ── Construcción ──────────────────────────────────────────────────────

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
          width: 460,
          child: AbsorbPointer(
            absorbing: _guardando,
            child: SingleChildScrollView(child: _cuerpo()),
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

  Widget _cuerpo() {
    if (widget.cargandoVenta) {
      return _MensajeCatalogo(
        mensaje: 'Cargando el catálogo de venta…',
        cargando: true,
      );
    }
    if (widget.ventaErrorMessage != null) {
      return _MensajeCatalogo(
        mensaje: 'No se pudo cargar el catálogo de venta. '
            'Sin él no se pueden elegir las formas de venta.',
        detalle: widget.ventaErrorMessage,
        onReintentar: widget.onReintentarVenta,
      );
    }
    if (widget.catalogoVenta == null) {
      return _MensajeCatalogo(
        mensaje: 'Todavía no sabemos cómo se vende en tu negocio. '
            'Completa la configuración del catálogo o reintenta.',
        onReintentar: widget.onReintentarVenta,
      );
    }
    return _formulario();
  }

  Widget _formulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _foto(),
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
        DropdownButtonFormField<String>(
          initialValue: _categoria.isNotBlank ? _categoria : null,
          decoration: const InputDecoration(labelText: 'Categoría *'),
          items: _categoriasEfectivas
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _categoria = v ?? ''),
        ),
        const SizedBox(height: 14),
        SelectorModoVenta(
          modosDisponibles: _modosDisponibles,
          seleccionado: _modoVista,
          onCambio: _cambiarModo,
        ),
        const SizedBox(height: 14),
        if (_modoVista == ModoVenta.medida)
          SeccionMedidaProducto(
            medidasActivas: _medidasActivas,
            familia: _medidaFamilia,
            unidadVisual: _medidaUnidad,
            precioController: _precioMedidaCtrl,
            referenciaController: _referenciaCtrl,
            stockController: _stockMedidaCtrl,
            stockInfinito: _esStockInfinito,
            resumenPrecio: _resumenPrecioMedida,
            errorReferencia: _errorDe(_referencia),
            errorStock: _errorDe(_stockMedida),
            etiquetaGuardada: _etiquetaLegacy(),
            onFamiliaCambiada: _cambiarFamilia,
            onUnidadCambiada: (unidad) =>
                setState(() => _medidaUnidad = unidad),
            onStockInfinitoCambiado: (valor) =>
                setState(() => _esStockInfinito = valor),
            onCambioTexto: _trasCambioTexto,
          )
        else
          SeccionPresentacionProducto(
            presentaciones: _presentacionesActivas,
            presentacionId: _presentacionId,
            formatoEtiqueta: _formatoEtiqueta,
            precioController: _precioPresentacionCtrl,
            stockController: _stockPresentacionCtrl,
            stockInfinito: _esStockInfinito,
            etiquetaGuardada: _etiquetaLegacy(),
            onPresentacionCambiada: _cambiarPresentacion,
            onFormatoCambiado: (formato) => setState(() {
              _formato = formato;
              _formatoEtiqueta = _etiquetaDeFormato(formato);
            }),
            onStockInfinitoCambiado: (valor) =>
                setState(() => _esStockInfinito = valor),
            onCambioTexto: () => setState(() {}),
          ),
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
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tiene delivery', style: TextStyle(fontSize: 13)),
          value: _tieneDelivery,
          onChanged: (v) => setState(() => _tieneDelivery = v),
        ),
      ],
    );
  }

  String _etiquetaDeFormato(FormatoElegido formato) {
    final familia = FamiliaUnidad.values.firstWhere(
      (familia) => familia.name == formato.familia,
      orElse: () => FamiliaUnidad.conteo,
    );
    final unidad = _unidadRegistrada(formato.unidad);
    if (unidad == null) return '';
    try {
      return FormatoPresentacion(
        valorBase: formato.valorBase,
        familia: familia,
        unidadVisible: unidad,
      ).etiqueta;
    } catch (_) {
      return '';
    }
  }

  String? _errorDe(ConversionCantidad? conversion) {
    if (conversion == null) return null;
    return conversion.error;
  }

  String _etiquetaLegacy() {
    final producto = widget.producto;
    if (producto == null) return '';
    if (producto.presentacionId.isNotEmpty) return '';
    return producto.etiquetaUnidad;
  }

  List<String> get _categoriasEfectivas {
    final categorias = <String>{...widget.categoriasDisponibles};
    final categoriaGuardada = widget.producto?.categoria ?? '';
    if (categoriaGuardada.isNotBlank) categorias.add(categoriaGuardada);
    return categorias.toList();
  }

  Widget _foto() {
    return GestureDetector(
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
                  ? Image.network(_urlImagenActual, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        'Foto del producto (opcional)\ntoca para elegir',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    )),
      ),
    );
  }
}

/// Estado del cuerpo cuando el catálogo de venta no está disponible:
/// mensaje claro y botón Reintentar (regla 5: nunca un formulario inútil
/// ni un FAB mudo en el origen).
class _MensajeCatalogo extends StatelessWidget {
  const _MensajeCatalogo({
    required this.mensaje,
    this.detalle,
    this.cargando = false,
    this.onReintentar,
  });

  final String mensaje;
  final String? detalle;
  final bool cargando;
  final Future<void> Function()? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cargando) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
          ],
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 8),
            Text(
              detalle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
          if (onReintentar != null) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => onReintentar!(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reintentar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on String {
  bool get isNotBlank => trim().isNotEmpty;
}
