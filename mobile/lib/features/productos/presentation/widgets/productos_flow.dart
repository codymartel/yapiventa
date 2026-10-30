// ═════════════════════════════════════════════════════════════════════════
// ProductosFlow
// ═════════════════════════════════════════════════════════════════════════
// Coordinador reutilizable del listado de productos (patrón
// ConfiguracionNegocioFlow). Crea una sola instancia de los providers con
// dependencias inyectables (por defecto production()), dispara la carga
// inicial y monta ProductosContent + diálogos. Se puede embeker tanto en la
// ruta independiente /productos como dentro del dashboard.
//
// QUÉ HACE:
// - Crea ProductosProvider y CatalogoNegocioProvider en initState (una sola
//   vez, identidad estable entre reconstrucciones) y los libera en dispose.
// - Dispara la carga inicial (catalogo.cargar() y productos.cargarProductos()).
// - Coordina agregar/editar/eliminar/cambiar disponibilidad y los diálogos
//   propios de Productos (FormularioProducto, DialogoEliminarProducto).
// - Expone los providers al contenido y traduce la selección de plantilla a
//   un rubro (ValueChanged<String>) para que el embebedor navegue.
// - NO dibuja botones de agregar: el encabezado (desktop) y el FAB (móvil)
//   los decide ProductosContent con su ancho local.
//
// QUÉ NO HACE:
// - NO crea Scaffold, AppBar ni SafeArea (los provee quien lo embebe).
// - NO navega a rutas raíz (navigation) — se delega vía callbacks
//   (onVolver, onElegirPlantilla). Solo usa showDialog para sus diálogos.
// - NO toca repositorios, Firestore ni Cloudinary.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../negocio/catalogo_negocio_dependencies.dart';
import '../../../negocio/domain/models/catalogo_negocio.dart';
import '../../../negocio/presentation/providers/catalogo_negocio_provider.dart';
import '../../domain/models/producto.dart';
import '../../productos_dependencies.dart';
import '../providers/formulario_producto_controller.dart';
import '../providers/productos_provider.dart';
import 'dialogo_eliminar_producto.dart';
import 'formulario_producto.dart';
import 'productos_content.dart';

class ProductosFlow extends StatefulWidget {
  final String uid;
  final String? negocioId;
  final CatalogoNegocio catalogoInicial;
  final VoidCallback? onVolver;
  final ValueChanged<String>? onElegirPlantilla;
  final VoidCallback? onProgressChanged;

  /// Lleva a Configuración → Catálogo (presentaciones propias). Null: el
  /// formulario no muestra el enlace.
  final VoidCallback? onAbrirCatalogo;

  /// Avisa que se volvió de Configuración con «Guardar y volver al producto»:
  /// se reabre el formulario que quedó a medias.
  final ValueListenable<int>? volverAlProducto;
  final ProductosDependencies? productosDependencies;
  final CatalogoNegocioDependencies? catalogoDependencies;
  final bool mostrarPanelesLaterales;

  const ProductosFlow({
    super.key,
    required this.uid,
    required this.negocioId,
    required this.catalogoInicial,
    this.onVolver,
    this.onElegirPlantilla,
    this.onProgressChanged,
    this.onAbrirCatalogo,
    this.volverAlProducto,
    this.productosDependencies,
    this.catalogoDependencies,
    this.mostrarPanelesLaterales = true,
  });

  @override
  State<ProductosFlow> createState() => _ProductosFlowState();
}

class _ProductosFlowState extends State<ProductosFlow> {
  ProductosProvider? _provider;
  CatalogoNegocioProvider? _catalogoProvider;

  /// Se marca al ir a Configuración desde el formulario: al volver, el
  /// catálogo de venta se relee una vez para ver lo que se creó allá.
  bool _catalogoDesactualizado = false;

  /// Formulario a medias mientras se está en Configuración. Este flujo es su
  /// dueño: lo destruye al reabrirlo y cerrarlo, o al empezar uno nuevo.
  FormularioProductoController? _borrador;

  /// El diálogo abierto lo dejó en [_borrador] en vez de destruirlo.
  bool _borradorConservado = false;

  @override
  void initState() {
    super.initState();
    widget.volverAlProducto?.addListener(_reanudarBorrador);
    final uid = widget.uid;

    final catalogoDependencies =
        widget.catalogoDependencies ?? CatalogoNegocioDependencies.production();
    _catalogoProvider = CatalogoNegocioProvider(
      uid: uid,
      obtenerCatalogoNegocio: catalogoDependencies.obtenerCatalogoNegocio,
      obtenerCatalogoVenta: catalogoDependencies.obtenerCatalogoVenta,
      catalogoInicial: widget.catalogoInicial,
    )..cargar();

    final dependencies =
        widget.productosDependencies ?? ProductosDependencies.production();
    final negocioId = widget.negocioId;
    if (negocioId != null) {
      _provider = ProductosProvider(
        uid: uid,
        negocioId: negocioId,
        cambiarDisponibilidadProducto:
            dependencies.cambiarDisponibilidadProducto,
        crearProducto: dependencies.crearProducto,
        editarProducto: dependencies.editarProducto,
        eliminarProducto: dependencies.eliminarProducto,
        obtenerPaginaProductos: dependencies.obtenerPaginaProductos,
      )..cargarProductos();
    }
  }

  @override
  void didUpdateWidget(covariant ProductosFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volverAlProducto == widget.volverAlProducto) return;
    oldWidget.volverAlProducto?.removeListener(_reanudarBorrador);
    widget.volverAlProducto?.addListener(_reanudarBorrador);
  }

  @override
  void dispose() {
    widget.volverAlProducto?.removeListener(_reanudarBorrador);
    _borrador?.dispose();
    _provider?.dispose();
    _catalogoProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final catalogoProvider = _catalogoProvider;
    if (provider == null || catalogoProvider == null) {
      return Center(
        child: Text(
          'Inicia sesion para ver tus productos.',
          style: TextStyle(color: AppColors.texto),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([provider, catalogoProvider]),
      builder: (context, _) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: catalogoProvider),
          ],
          // Sin FAB acá: lo dibuja ProductosContent (_construirMovil) con la
          // misma medida local que elige entre lista y encabezado+cuadrícula.
          child: ProductosContent(
            mostrarPanelesLaterales: widget.mostrarPanelesLaterales,
            onAgregar: () => _abrirFormulario(),
            onEditar: (producto) => _abrirFormulario(producto: producto),
            onEliminar: _confirmarEliminacion,
            onElegirPlantilla: _elegirPlantilla,
          ),
        );
      },
    );
  }

  void _elegirPlantilla() {
    final rubro = _catalogoProvider?.catalogo?.rubro ?? '';
    widget.onElegirPlantilla?.call(rubro.isEmpty ? 'Otros' : rubro);
  }

  /// El formulario se fue a Configuración: queda guardado a medias.
  void _guardarBorradorEIr(FormularioProductoController formulario) {
    if (!identical(_borrador, formulario)) _borrador?.dispose();
    _borrador = formulario;
    _borradorConservado = true;
    _catalogoDesactualizado = true;
    widget.onAbrirCatalogo?.call();
  }

  /// Se volvió de Configuración: relee el catálogo (1 lectura) y reabre el
  /// formulario con lo que el vendedor había escrito.
  Future<void> _reanudarBorrador() async {
    final borrador = _borrador;
    if (borrador == null) return;
    await _abrirFormulario(borrador: borrador);
  }

  Future<void> _abrirFormulario({
    Producto? producto,
    FormularioProductoController? borrador,
  }) async {
    final provider = _provider;
    final catalogo = _catalogoProvider?.catalogo;
    if (provider == null || catalogo == null) return;
    // Un formulario nuevo descarta el borrador que hubiera quedado.
    if (borrador == null && _borrador != null) {
      _borrador!.dispose();
      _borrador = null;
    }
    if (_catalogoDesactualizado) {
      _catalogoDesactualizado = false;
      await _catalogoProvider?.recargarVenta();
      if (!mounted) return;
    }
    _borradorConservado = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: provider,
        child: FormularioProducto(
          producto: borrador?.producto ?? producto,
          borrador: borrador,
          categoriasDisponibles: catalogo.categorias,
          catalogoVenta: _catalogoProvider?.catalogoVenta,
          rubro: catalogo.rubro,
          cargandoVenta: _catalogoProvider?.cargandoVenta ?? false,
          ventaErrorMessage: _catalogoProvider?.ventaErrorMessage,
          onReintentarVenta: _catalogoProvider == null
              ? null
              : () => _catalogoProvider!.reintentarVenta(),
          onCancelar: () => Navigator.of(dialogContext).pop(),
          onGuardado: widget.onProgressChanged,
          onAbrirCatalogo: widget.onAbrirCatalogo == null
              ? null
              : _guardarBorradorEIr,
        ),
      ),
    );
    // Cerrado sin ir a Configuración: el borrador reabierto ya no sirve.
    if (borrador != null && !_borradorConservado) {
      if (identical(_borrador, borrador)) _borrador = null;
      borrador.dispose();
    }
  }

  Future<void> _confirmarEliminacion(String productoId) async {
    final provider = _provider;
    if (provider == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => const DialogoEliminarProducto(),
    );

    if (confirmar == true) {
      final eliminado = await provider.eliminarProducto(productoId);
      if (eliminado) widget.onProgressChanged?.call();
    }
  }
}
