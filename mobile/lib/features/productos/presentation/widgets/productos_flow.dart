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
// - Renderiza el FAB móvil "Agregar producto" superpuesto al contenido.
//
// QUÉ NO HACE:
// - NO crea Scaffold, AppBar ni SafeArea (los provee quien lo embebe).
// - NO navega a rutas raíz (navigation) — se delega vía callbacks
//   (onVolver, onElegirPlantilla). Solo usa showDialog para sus diálogos.
// - NO toca repositorios, Firestore ni Cloudinary.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../negocio/catalogo_negocio_dependencies.dart';
import '../../../negocio/domain/models/catalogo_negocio.dart';
import '../../../negocio/presentation/providers/catalogo_negocio_provider.dart';
import '../../domain/models/producto.dart';
import '../../productos_dependencies.dart';
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
  final ProductosDependencies? productosDependencies;
  final CatalogoNegocioDependencies? catalogoDependencies;

  const ProductosFlow({
    super.key,
    required this.uid,
    required this.negocioId,
    required this.catalogoInicial,
    this.onVolver,
    this.onElegirPlantilla,
    this.onProgressChanged,
    this.productosDependencies,
    this.catalogoDependencies,
  });

  @override
  State<ProductosFlow> createState() => _ProductosFlowState();
}

class _ProductosFlowState extends State<ProductosFlow> {
  ProductosProvider? _provider;
  CatalogoNegocioProvider? _catalogoProvider;

  @override
  void initState() {
    super.initState();
    final uid = widget.uid;

    final catalogoDependencies =
        widget.catalogoDependencies ?? CatalogoNegocioDependencies.production();
    _catalogoProvider = CatalogoNegocioProvider(
      uid: uid,
      obtenerCatalogoNegocio: catalogoDependencies.obtenerCatalogoNegocio,
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
  void dispose() {
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
        final esDesktop = MediaQuery.sizeOf(context).width >= 1100;
        final accionesHabilitadas =
            catalogoProvider.disponible &&
            !provider.cargando &&
            !provider.refrescando &&
            !provider.cargandoMas &&
            !provider.creandoProducto &&
            !provider.editandoProducto;

        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: catalogoProvider),
          ],
          child: Stack(
            children: [
              ProductosContent(
                onAgregar: () => _abrirFormulario(),
                onEditar: (producto) => _abrirFormulario(producto: producto),
                onEliminar: _confirmarEliminacion,
                onElegirPlantilla: _elegirPlantilla,
              ),
              if (!esDesktop)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    tooltip: catalogoProvider.disponible
                        ? 'Agregar producto'
                        : catalogoProvider.errorMessage != null
                        ? 'No se pudo cargar el catálogo'
                        : 'Cargando configuración del catálogo',
                    onPressed: accionesHabilitadas
                        ? () => _abrirFormulario()
                        : null,
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar producto'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _elegirPlantilla() {
    final rubro = _catalogoProvider?.catalogo?.rubro ?? '';
    widget.onElegirPlantilla?.call(rubro.isEmpty ? 'Otros' : rubro);
  }

  Future<void> _abrirFormulario({Producto? producto}) {
    final provider = _provider;
    final catalogo = _catalogoProvider?.catalogo;
    if (provider == null || catalogo == null) {
      return Future<void>.value();
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: provider,
        child: FormularioProducto(
          producto: producto,
          categoriasDisponibles: catalogo.categorias,
          unidadesDisponibles: catalogo.unidadesMedida,
          onCancelar: () => Navigator.of(dialogContext).pop(),
          onGuardado: widget.onProgressChanged,
        ),
      ),
    );
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
