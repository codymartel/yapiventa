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
  });

  @override
  State<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  late final FormularioProductoController _form = FormularioProductoController(
    producto: widget.producto,
    categoriasDisponibles: widget.categoriasDisponibles,
    catalogoVenta: widget.catalogoVenta,
    rubro: widget.rubro,
  );

  @override
  void didUpdateWidget(covariant FormularioProducto oldWidget) {
    super.didUpdateWidget(oldWidget);
    _form.catalogoVenta = widget.catalogoVenta;
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) {
        final guardando = _form.guardando;
        final falta = _form.queFalta;
        return PopScope(
          canPop: !guardando,
          child: AlertDialog(
            backgroundColor: AppColors.superficie,
            title: Text(
              widget.producto == null ? 'Agregar producto' : 'Editar producto',
              style: TextStyle(color: AppColors.texto),
            ),
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
                  child: Text(
                    falta,
                    key: const Key('falta-para-guardar'),
                    style: TextStyle(
                      color: AppColors.aviso,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              TextButton(
                onPressed: guardando ? null : widget.onCancelar,
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              ElevatedButton(
                onPressed: _form.camposOk ? _guardar : null,
                child: guardando
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
      },
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
          ),
        if (form.modelos.usa) ...[
          const SizedBox(height: 14),
          ListaModelosProducto(
            modelos: form.modelos,
            porMedida: form.modoVista == ModoVenta.medida,
            stockInfinito: form.esStockInfinito,
            habilitada: !form.guardando,
            formatos: form.formatosDePresentacion,
            referencia: form.medida.referenciaEtiqueta,
            unidad: form.medida.unidad,
            factorStock: LecturaUnidadesProducto.factorDe(form.medida.unidad),
            unidadBase: form.medida.unidadBaseNombre,
          ),
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
