// ═════════════════════════════════════════════════════════════════════════
// ProductosScreen
// ═════════════════════════════════════════════════════════════════════════
// Listado manualmente paginado de productos. La pantalla crea una sola
// instancia del provider por apertura de la ruta y dispara la primera carga
// desde initState; los rebuilds solo leen el estado ya cargado.
// ═════════════════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../negocio/catalogo_negocio_dependencies.dart';
import '../../../negocio/presentation/providers/catalogo_negocio_provider.dart';
import '../../domain/models/producto.dart';
import '../../productos_dependencies.dart';
import '../providers/productos_provider.dart';
import '../widgets/dialogo_eliminar_producto.dart';
import '../widgets/formulario_producto.dart';
import '../widgets/producto_card.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  ProductosProvider? _provider;
  CatalogoNegocioProvider? _catalogoProvider;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final catalogoDependencies = CatalogoNegocioDependencies.production();
    _catalogoProvider = CatalogoNegocioProvider(
      uid: uid,
      obtenerCatalogoNegocio: catalogoDependencies.obtenerCatalogoNegocio,
    )..cargar();

    final dependencies = ProductosDependencies.production();
    _provider = ProductosProvider(
      uid: uid,
      repository: dependencies.repository,
      crearProducto: dependencies.crearProducto,
      editarProducto: dependencies.editarProducto,
      eliminarProducto: dependencies.eliminarProducto,
      obtenerPaginaProductos: dependencies.obtenerPaginaProductos,
    )..cargarProductos();
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider.value(value: catalogoProvider),
      ],
      child: const _ContenidoProductos(),
    );
  }
}

class _ContenidoProductos extends StatelessWidget {
  const _ContenidoProductos();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductosProvider>();
    final catalogoProvider = context.watch<CatalogoNegocioProvider>();
    final productos = provider.productosFiltrados;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.superficie,
        foregroundColor: AppColors.texto,
        title: const Text('Productos'),
        actions: [
          IconButton(
            tooltip: 'Editar configuración del negocio',
            onPressed: () => Navigator.of(context).pushNamed('/elegir-rubro'),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  if (catalogoProvider.errorMessage != null) ...[
                    _MensajeError(
                      mensaje: catalogoProvider.errorMessage!,
                      onCerrar: catalogoProvider.reintentar,
                      tooltip: 'Reintentar carga del catálogo',
                      icono: Icons.refresh,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (provider.errorMessage != null) ...[
                    _MensajeError(
                      mensaje: provider.errorMessage!,
                      onCerrar: provider.limpiarError,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: provider.cargando && productos.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : productos.isEmpty && !provider.hayMas
                        ? Center(
                            child: Text(
                              'Todavia no tienes productos.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        : ListView.builder(
                            // No usa ScrollController: la siguiente pagina se
                            // solicita exclusivamente al pulsar "Ver mas".
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount:
                                productos.length + (provider.hayMas ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == productos.length) {
                                return _BotonVerMas(provider: provider);
                              }

                              final producto = productos[index];
                              return ProductoCard(
                                key: ValueKey(producto.id),
                                producto: producto,
                                onEditar: catalogoProvider.disponible
                                    ? () => _abrirFormulario(
                                        context,
                                        provider,
                                        producto: producto,
                                      )
                                    : () {},
                                onEliminar: () => _confirmarEliminacion(
                                  context,
                                  provider,
                                  producto.id,
                                ),
                                onToggleDisponible: () {
                                  provider.toggleDisponible(
                                    producto.id,
                                    !producto.disponible,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: catalogoProvider.disponible
            ? 'Agregar producto'
            : catalogoProvider.errorMessage != null
            ? 'No se pudo cargar el catálogo'
            : 'Cargando configuración del catálogo',
        onPressed: catalogoProvider.disponible
            ? () => _abrirFormulario(context, provider)
            : null,
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
    );
  }

  Future<void> _abrirFormulario(
    BuildContext context,
    ProductosProvider provider, {
    Producto? producto,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: provider,
        child: FormularioProducto(
          producto: producto,
          categoriasDisponibles: context
              .read<CatalogoNegocioProvider>()
              .catalogo!
              .categorias,
          unidadesDisponibles: context
              .read<CatalogoNegocioProvider>()
              .catalogo!
              .unidadesMedida,
          onCancelar: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminacion(
    BuildContext context,
    ProductosProvider provider,
    String productoId,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => const DialogoEliminarProducto(),
    );

    if (confirmar == true) {
      await provider.eliminarProducto(productoId);
    }
  }
}

class _BotonVerMas extends StatelessWidget {
  final ProductosProvider provider;

  const _BotonVerMas({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: provider.cargandoMas ? null : provider.cargarMasProductos,
          icon: provider.cargandoMas
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(provider.cargandoMas ? 'Cargando...' : 'Ver mas'),
        ),
      ),
    );
  }
}

class _MensajeError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onCerrar;
  final String tooltip;
  final IconData icono;

  const _MensajeError({
    required this.mensaje,
    required this.onCerrar,
    this.tooltip = 'Cerrar mensaje',
    this.icono = Icons.close,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(mensaje, style: TextStyle(color: AppColors.texto)),
          ),
          IconButton(
            tooltip: tooltip,
            onPressed: onCerrar,
            icon: Icon(icono, size: 18),
          ),
        ],
      ),
    );
  }
}
