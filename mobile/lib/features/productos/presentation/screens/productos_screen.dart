// ═════════════════════════════════════════════════════════════════════════
// ProductosScreen
// ═════════════════════════════════════════════════════════════════════════
// Pantalla de productos. Crea una sola instancia de los providers con
// dependencias inyectables (por defecto production()), los expone al árbol
// y delega el contenido resposivo a ProductosContent. Todo lo que requiere
// Scaffold, AppBar, SafeArea, FAB o Navigator vive aquí; el contenido puro
// vive en ProductosContent (widgets/productos_content.dart).
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
import '../widgets/dialogo_eliminar_producto.dart';
import '../widgets/formulario_producto.dart';
import '../widgets/productos_content.dart';

class ProductosScreen extends StatefulWidget {
  final String uid;
  final String? negocioId;
  final CatalogoNegocio catalogoInicial;
  final VoidCallback? onProgressChanged;
  final ProductosDependencies? productosDependencies;
  final CatalogoNegocioDependencies? catalogoDependencies;

  const ProductosScreen({
    super.key,
    required this.uid,
    required this.negocioId,
    required this.catalogoInicial,
    this.onProgressChanged,
    this.productosDependencies,
    this.catalogoDependencies,
  });

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
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
      return Scaffold(
        backgroundColor: AppColors.fondo,
        body: Center(
          child: Text(
            'Inicia sesion para ver tus productos.',
            style: TextStyle(color: AppColors.texto),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([provider, catalogoProvider]),
      builder: (context, _) {
        final catalogo = catalogoProvider.catalogo;
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
          child: Scaffold(
            backgroundColor: AppColors.fondo,
            appBar: AppBar(
              backgroundColor: AppColors.superficie,
              foregroundColor: AppColors.texto,
              title: const Text('Productos'),
              actions: [
                IconButton(
                  tooltip: 'Editar configuración del negocio',
                  onPressed: catalogo == null
                      ? null
                      : () => Navigator.of(context).pushNamed(
                          '/configurar-negocio',
                          arguments: {
                            'rubro': catalogo.rubro.isEmpty
                                ? 'Otros'
                                : catalogo.rubro,
                            'configuracionInicial':
                                catalogo.configuracionInicial,
                          },
                        ),
                  icon: const Icon(Icons.store_outlined),
                ),
                IconButton(
                  tooltip: 'Actualizar productos',
                  onPressed:
                      provider.cargando ||
                          provider.refrescando ||
                          provider.cargandoMas
                      ? null
                      : provider.refrescar,
                  icon: provider.refrescando
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            body: SafeArea(
              child: ProductosContent(
                onAgregar: () => _abrirFormulario(),
                onEditar: (producto) => _abrirFormulario(producto: producto),
                onEliminar: _confirmarEliminacion,
                onElegirPlantilla: _elegirPlantilla,
              ),
            ),
            floatingActionButton: esDesktop
                ? null
                : FloatingActionButton.extended(
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
        );
      },
    );
  }

  void _elegirPlantilla() {
    final catalogo = _catalogoProvider?.catalogo;
    if (catalogo == null) return;
    Navigator.of(context).pushNamed(
      '/elegir-plantilla',
      arguments: {'rubro': catalogo.rubro.isEmpty ? 'Otros' : catalogo.rubro},
    );
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
