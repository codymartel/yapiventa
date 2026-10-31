import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../application/services/lectura_unidades_producto.dart';
import '../../domain/models/modo_venta.dart';
import '../../domain/models/producto.dart';
import '../providers/formulario_producto_controller.dart';
import '../providers/productos_provider.dart';
import 'formulario/foto_producto.dart';
import 'formulario/lista_modelos_producto.dart';
import 'formulario/mensaje_catalogo.dart';
import 'formulario/pregunta_modelos_producto.dart';
import 'formulario/seccion_combo_producto.dart';
import 'formulario/seccion_extras_producto.dart';
import 'formulario/seccion_medida_producto.dart';
import 'formulario/seccion_presentacion_producto.dart';
import 'formulario/selector_modo_venta.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioProducto
// ═════════════════════════════════════════════════════════════════════════
// Diálogo para crear o editar un producto, conducido por el catálogo de
// venta del negocio (presentaciones y medidas activas).
//
// Solo dibuja: el estado y las validaciones viven en
// FormularioProductoController; el armado del Producto, en
// ConstructorProducto. Si el catálogo de venta no cargó (o falló), el cuerpo
// muestra el motivo y un botón Reintentar.
// ═════════════════════════════════════════════════════════════════════════

class FormularioProducto extends StatefulWidget {
  final Producto? producto;
  final List<String> categoriasDisponibles;

  /// Catálogo de venta del negocio (presentaciones y medidas activas).
  final CatalogoVentaPersistido? catalogoVenta;

  /// Rubro del negocio: decide las palabras que se sugieren para nombrar lo
  /// que cambia (Color, Aroma, Sabor…).
  final String rubro;
  final bool cargandoVenta;
  final String? ventaErrorMessage;
  final Future<void> Function()? onReintentarVenta;

  final VoidCallback onCancelar;
  final VoidCallback? onGuardado;

  /// Va a Configuración → Catálogo (presentaciones propias) y entrega el
  /// formulario tal como está, para reabrirlo al volver. Null donde no hay a
  /// dónde ir: el enlace no aparece.
  final ValueChanged<FormularioProductoController>? onAbrirCatalogo;

  /// Formulario a medias que se reabre al volver de Configuración. Quien lo
  /// pasa es su dueño: este widget no lo destruye.
  final FormularioProductoController? borrador;

  /// Los productos cargados en el panel: de aquí se eligen las partes de un
  /// combo y se calcula su stock.
  final List<Producto> productosParaCombo;

  /// En celular el formulario es una hoja grande que sube desde abajo, con los
  /// botones fijos al pie; en PC, un diálogo centrado.
  final bool enHoja;

  const FormularioProducto({
    super.key,
    this.producto,
    required this.categoriasDisponibles,
    required this.catalogoVenta,
    this.rubro = '',
    this.cargandoVenta = false,
    this.ventaErrorMessage,
    this.onReintentarVenta,
    required this.onCancelar,
    this.onGuardado,
    this.onAbrirCatalogo,
    this.borrador,
    this.productosParaCombo = const [],
    this.enHoja = false,
  });

  @override
  State<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  late final FormularioProductoController _form =
      widget.borrador ??
      FormularioProductoController(
        producto: widget.producto,
        categoriasDisponibles: widget.categoriasDisponibles,
        catalogoVenta: widget.catalogoVenta,
        rubro: widget.rubro,
        productosParaCombo: widget.productosParaCombo,
      );

  /// Se marca al ir a Configuración: el formulario sigue vivo fuera de este
  /// diálogo y su dueño lo destruye.
  bool _conservar = false;

  @override
  void initState() {
    super.initState();
    // Un borrador reabierto puede traer un catálogo anterior.
    _form.catalogoVenta = widget.catalogoVenta;
  }

  @override
  void didUpdateWidget(covariant FormularioProducto oldWidget) {
    super.didUpdateWidget(oldWidget);
    _form.catalogoVenta = widget.catalogoVenta;
  }

  @override
  void dispose() {
    if (widget.borrador == null && !_conservar) _form.dispose();
    super.dispose();
  }

  /// Cierra el diálogo sin perder lo escrito: el flujo guarda el formulario y
  /// lo reabre cuando se vuelve de Configuración.
  void _irACatalogo() {
    final abrir = widget.onAbrirCatalogo;
    if (abrir == null || _form.guardando) return;
    _conservar = true;
    widget.onCancelar();
    abrir(_form);
  }

  Future<void> _guardar() async {
    if (!_form.camposOk) return;
    _form.guardando = true;
    final nuevo = _form.construirProducto();
    // Con variables no hay foto principal: la portada sale del primer modelo.
    final fotoPrincipal = _form.modelos.usa ? null : _form.fotoNuevaBytes;
    final nombreFoto = _form.modelos.usa ? null : _form.fotoNueva?.name;

    final provider = context.read<ProductosProvider>();
    final exito = widget.producto == null
        ? await provider.crearProducto(
            nuevo,
            imagenBytes: fotoPrincipal,
            nombreArchivo: nombreFoto,
            fotosModelos: _form.fotosModelos,
          )
        : await provider.guardarProducto(
            nuevo,
            imagenBytes: fotoPrincipal,
            nombreArchivo: nombreFoto,
            fotosModelos: _form.fotosModelos,
          );

    if (!mounted) return;
    _form.guardando = false;
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

  String get _titulo =>
      widget.producto == null ? 'Agregar producto' : 'Editar producto';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) {
        final guardando = _form.guardando;
        final falta = _form.queFalta;
        return PopScope(
          canPop: !guardando,
          child: widget.enHoja
              ? _hoja(guardando, falta)
              : _dialogo(guardando, falta),
        );
      },
    );
  }

  Widget _textoFalta(String falta) => Text(
    falta,
    key: const Key('falta-para-guardar'),
    style: TextStyle(
      color: AppColors.aviso,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _contenidoBotonGuardar(bool guardando) {
    if (!guardando) return const Text('Guardar producto');
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        SizedBox(width: 8),
        Text('Guardando...'),
      ],
    );
  }

  /// PC: el diálogo centrado de siempre.
  Widget _dialogo(bool guardando, String? falta) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      title: Text(_titulo, style: TextStyle(color: AppColors.texto)),
      content: SizedBox(
        width: 460,
        child: AbsorbPointer(
          absorbing: guardando,
          child: SingleChildScrollView(child: _cuerpo()),
        ),
      ),
      actions: [
        if (falta != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: _textoFalta(falta),
          ),
        TextButton(
          onPressed: guardando ? null : widget.onCancelar,
          child: Text('Cancelar', style: TextStyle(color: AppColors.muted)),
        ),
        ElevatedButton(
          onPressed: _form.camposOk ? _guardar : null,
          child: _contenidoBotonGuardar(guardando),
        ),
      ],
    );
  }

  /// Celular: una hoja grande con título, cuerpo que se desplaza y los botones
  /// fijos al pie (siempre a la vista, sin buscarlos al final del formulario).
  Widget _hoja(bool guardando, String? falta) {
    return Column(
      key: const Key('formulario-en-hoja'),
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.dim,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _titulo,
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: AbsorbPointer(
            absorbing: guardando,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _cuerpo(),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.bordeSutil)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (falta != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _textoFalta(falta),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const Key('cancelar-formulario'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: guardando ? null : widget.onCancelar,
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _form.camposOk ? _guardar : null,
                      child: _contenidoBotonGuardar(guardando),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cuerpo() {
    if (widget.cargandoVenta) {
      return const MensajeCatalogo(
        mensaje: 'Cargando el catálogo de venta…',
        cargando: true,
      );
    }
    if (widget.ventaErrorMessage != null) {
      return MensajeCatalogo(
        mensaje:
            'No se pudo cargar el catálogo de venta. '
            'Sin él no se pueden elegir las formas de venta.',
        detalle: widget.ventaErrorMessage,
        onReintentar: widget.onReintentarVenta,
      );
    }
    if (widget.catalogoVenta == null) {
      return MensajeCatalogo(
        mensaje:
            'Todavía no sabemos cómo se vende en tu negocio. '
            'Completa la configuración del catálogo o reintenta.',
        onReintentar: widget.onReintentarVenta,
      );
    }
    return _formulario();
  }

  Widget _formulario() {
    final form = _form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!form.modelos.usa) ...[
          FotoProducto(
            fotoNuevaBytes: form.fotoNuevaBytes,
            urlImagenActual: form.urlImagenActual,
            habilitada: !form.guardando,
            onFotoElegida: form.elegirFoto,
            mosaico: form.combo.usa ? form.combo.fotosDeLasPartes : const [],
            textoVacio: form.combo.usa
                ? 'Foto del ${form.combo.nombre.palabra} *\ntoca para elegir'
                : 'Foto del producto *\ntoca para elegir',
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: form.nombreCtrl,
          onChanged: (_) => form.trasCambioTexto(),
          style: TextStyle(color: AppColors.texto),
          decoration: const InputDecoration(labelText: 'Nombre del producto *'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: form.categoria.trim().isNotEmpty
              ? form.categoria
              : null,
          decoration: const InputDecoration(labelText: 'Categoría *'),
          items: form.categoriasEfectivas
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => form.cambiarCategoria(v ?? ''),
        ),
        const SizedBox(height: 14),
        SeccionComboProducto(combo: form.combo),
        if (!form.combo.usa) ...[
          SelectorModoVenta(
            modosDisponibles: form.modosDisponibles,
            seleccionado: form.modoVista,
            onCambio: form.cambiarModo,
          ),
          const SizedBox(height: 14),
          PreguntaModelosProducto(
            modelos: form.modelos,
            porMedida: form.modoVista == ModoVenta.medida,
          ),
          const SizedBox(height: 14),
          if (form.modoVista == ModoVenta.medida)
            SeccionMedidaProducto(
              medida: form.medida,
              stockInfinito: form.esStockInfinito,
              etiquetaGuardada: form.etiquetaLegacy,
              onStockInfinitoCambiado: form.cambiarStockInfinito,
              conModelos: form.modelos.usa,
            )
          else
            SeccionPresentacionProducto(
              conModelos: form.modelos.usa,
              presentaciones: form.presentacionesActivas,
              presentacionId: form.presentacionId,
              formatoEtiqueta: form.formatoEtiqueta,
              textoPrecio: form.textoPrecioPresentacion,
              unidadStock: form.unidadStockPresentacion,
              precioController: form.precioPresentacionCtrl,
              stockController: form.stockPresentacionCtrl,
              stockInfinito: form.esStockInfinito,
              etiquetaGuardada: form.etiquetaLegacy,
              onPresentacionCambiada: form.cambiarPresentacion,
              onFormatoCambiado: form.cambiarFormato,
              onStockInfinitoCambiado: form.cambiarStockInfinito,
              onCambioTexto: form.trasCambioTexto,
              onAbrirCatalogo: widget.onAbrirCatalogo == null
                  ? null
                  : _irACatalogo,
            ),
          if (form.modelos.usa) ...[
            const SizedBox(height: 14),
            ListaModelosProducto(
              modelos: form.modelos,
              porMedida: form.modoVista == ModoVenta.medida,
              stockInfinito: form.esStockInfinito,
              habilitada: !form.guardando,
              formatos: form.formatosDePresentacion,
              nombreEnvase: form.nombrePresentacion,
              referencia: form.medida.referenciaEtiqueta,
              unidad: form.medida.unidad,
              factorStock: LecturaUnidadesProducto.factorDe(form.medida.unidad),
              unidadBase: form.medida.unidadBaseNombre,
            ),
          ],
        ],
        if (form.modoVista != ModoVenta.medida || form.combo.usa) ...[
          const SizedBox(height: 14),
          SeccionExtrasProducto(extras: form.extras),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: form.descripcionCtrl,
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
          value: form.tieneDelivery,
          onChanged: form.cambiarDelivery,
        ),
      ],
    );
  }
}
