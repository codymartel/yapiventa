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
      cambiarDisponibilidadProducto: dependencies.cambiarDisponibilidadProducto,
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
      child: const ContenidoProductos(),
    );
  }
}

class ContenidoProductos extends StatelessWidget {
  final bool mostrarGuiaConfiguracion;

  const ContenidoProductos({super.key, this.mostrarGuiaConfiguracion = true});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductosProvider>();
    final catalogoProvider = context.watch<CatalogoNegocioProvider>();
    final catalogo = catalogoProvider.catalogo;
    final productos = provider.productosFiltrados;
    final esDesktop = MediaQuery.sizeOf(context).width >= 1100;
    final accionesHabilitadas =
        catalogoProvider.disponible &&
        !provider.cargando &&
        !provider.refrescando &&
        !provider.cargandoMas &&
        !provider.creandoProducto &&
        !provider.editandoProducto;

    return Scaffold(
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
                      'configuracionInicial': catalogo.configuracionInicial,
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
        child: esDesktop
            ? _construirDesktop(context, provider, catalogoProvider, productos)
            : _construirMovil(context, provider, catalogoProvider, productos),
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
                  ? () => _abrirFormulario(context, provider)
                  : null,
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Agregar producto'),
            ),
    );
  }

  Widget _construirMovil(
    BuildContext context,
    ProductosProvider provider,
    CatalogoNegocioProvider catalogoProvider,
    List<Producto> productos,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              ..._mensajes(provider, catalogoProvider),
              Expanded(
                child: provider.cargando && productos.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : productos.isEmpty && !provider.hayMas
                    ? const _CatalogoVacio()
                    : ListView.builder(
                        // La siguiente pagina se solicita solo con "Ver más".
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount:
                            productos.length +
                            (provider.hayMas ? 1 : 0) +
                            (provider.totalProductos > 0 ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index ==
                              productos.length + (provider.hayMas ? 1 : 0)) {
                            return _BotonElegirPlantilla(
                              catalogoProvider: catalogoProvider,
                            );
                          }
                          if (index == productos.length) {
                            return _BotonVerMas(provider: provider);
                          }
                          return _construirProductoCard(
                            context,
                            provider,
                            catalogoProvider,
                            productos[index],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirDesktop(
    BuildContext context,
    ProductosProvider provider,
    CatalogoNegocioProvider catalogoProvider,
    List<Producto> productos,
  ) {
    final escalaTexto = MediaQuery.textScalerOf(context).scale(1);
    final alturaTarjeta =
        356 + ((escalaTexto - 1).clamp(0, 2).toDouble() * 100);
    final agregarHabilitado =
        catalogoProvider.disponible &&
        !provider.cargando &&
        !provider.refrescando &&
        !provider.cargandoMas &&
        !provider.creandoProducto &&
        !provider.editandoProducto;
    return SingleChildScrollView(
      key: const Key('productos-page-scroll'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1680),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mostrarGuiaConfiguracion) ...[
                const SizedBox(width: 196, child: FasesNegocioPanel()),
                const SizedBox(width: 18),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EncabezadoProductos(
                      agregarHabilitado: agregarHabilitado,
                      onAgregar: () => _abrirFormulario(context, provider),
                    ),
                    const SizedBox(height: 18),
                    ..._mensajes(provider, catalogoProvider),
                    if (provider.cargando && productos.isEmpty)
                      const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (productos.isEmpty && !provider.hayMas)
                      const SizedBox(height: 320, child: _CatalogoVacio())
                    else ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columnas = constraints.maxWidth >= 1000 ? 4 : 3;
                          return GridView.builder(
                            key: const Key('productos-grid'),
                            shrinkWrap: true,
                            primary: false,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: productos.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columnas,
                                  mainAxisExtent: alturaTarjeta,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                            itemBuilder: (context, index) =>
                                _construirProductoCard(
                                  context,
                                  provider,
                                  catalogoProvider,
                                  productos[index],
                                  esCuadricula: true,
                                ),
                          );
                        },
                      ),
                      if (provider.hayMas) _BotonVerMas(provider: provider),
                      if (provider.totalProductos > 0) ...[
                        const SizedBox(height: 12),
                        _BotonElegirPlantilla(
                          catalogoProvider: catalogoProvider,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 18),
              const SizedBox(width: 224, child: AyudaProductosPanel()),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _mensajes(
    ProductosProvider provider,
    CatalogoNegocioProvider catalogoProvider,
  ) {
    return [
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
    ];
  }

  Widget _construirProductoCard(
    BuildContext context,
    ProductosProvider provider,
    CatalogoNegocioProvider catalogoProvider,
    Producto producto, {
    bool esCuadricula = false,
  }) {
    final cambiandoDisponibilidad = provider.cambiandoDisponibilidad(
      producto.id,
    );
    final accionesHabilitadas =
        !provider.cargando &&
        !provider.refrescando &&
        !provider.cargandoMas &&
        !provider.creandoProducto &&
        !provider.editandoProducto &&
        !cambiandoDisponibilidad;
    return ProductoCard(
      key: ValueKey(producto.id),
      producto: producto,
      esCuadricula: esCuadricula,
      cambiandoDisponibilidad: cambiandoDisponibilidad,
      onEditar: catalogoProvider.disponible && accionesHabilitadas
          ? () => _abrirFormulario(context, provider, producto: producto)
          : null,
      onEliminar: accionesHabilitadas
          ? () => _confirmarEliminacion(context, provider, producto.id)
          : null,
      onToggleDisponible: accionesHabilitadas
          ? () => provider.toggleDisponible(producto.id, !producto.disponible)
          : null,
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
    final cargando =
        provider.cargando || provider.refrescando || provider.cargandoMas;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: cargando ? null : provider.cargarMasProductos,
          icon: cargando
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(cargando ? 'Cargando...' : 'Ver más'),
        ),
      ),
    );
  }
}

class _BotonElegirPlantilla extends StatelessWidget {
  final CatalogoNegocioProvider catalogoProvider;

  const _BotonElegirPlantilla({required this.catalogoProvider});

  @override
  Widget build(BuildContext context) {
    final catalogo = catalogoProvider.catalogo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: FilledButton.icon(
          onPressed: catalogo == null
              ? null
              : () => Navigator.of(context).pushNamed(
                  '/elegir-plantilla',
                  arguments: {
                    'rubro': catalogo.rubro.isEmpty ? 'Otros' : catalogo.rubro,
                    'plantillaActual':
                        catalogo.configuracionInicial['plantilla'] as String? ??
                            '',
                  },
                ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Siguiente paso: elegir plantilla'),
        ),
      ),
    );
  }
}

class _EncabezadoProductos extends StatelessWidget {
  final bool agregarHabilitado;
  final VoidCallback onAgregar;

  const _EncabezadoProductos({
    required this.agregarHabilitado,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Productos',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestiona los productos de tu catálogo',
                style: TextStyle(
                  color: AppColors.texto.withValues(alpha: 0.75),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: agregarHabilitado ? onAgregar : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Agregar producto'),
        ),
      ],
    );
  }
}

class _CatalogoVacio extends StatelessWidget {
  const _CatalogoVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Todavía no tienes productos.',
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}

class FasesNegocioPanel extends StatelessWidget {
  const FasesNegocioPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return _PanelLateral(
      key: const Key('fases-negocio-panel'),
      titulo: 'Fases de tu negocio',
      child: const Column(
        children: [
          _FaseNegocio(texto: '1. Rubro', completada: true),
          _FaseNegocio(texto: '2. Configuración del negocio', completada: true),
          _FaseNegocio(
            texto: '3. Agregado de productos',
            actual: true,
            mostrarLinea: false,
          ),
        ],
      ),
    );
  }
}

class AyudaProductosPanel extends StatelessWidget {
  const AyudaProductosPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return _PanelLateral(
      key: const Key('ayuda-productos-panel'),
      titulo: '¿Cómo funciona?',
      child: const Column(
        children: [
          _AyudaProducto(
            icono: Icons.add_photo_alternate_outlined,
            titulo: 'Agregar producto',
            descripcion: 'Crea un producto con imagen, precio y stock.',
          ),
          _AyudaProducto(
            icono: Icons.edit_outlined,
            titulo: 'Editar',
            descripcion: 'Modifica sus datos.',
          ),
          _AyudaProducto(
            icono: Icons.visibility_outlined,
            titulo: 'Disponibilidad',
            descripcion: 'Activa o desactiva su publicación.',
          ),
          _AyudaProducto(
            icono: Icons.delete_outline,
            titulo: 'Eliminar',
            descripcion: 'Quita el producto del catálogo.',
            ultimo: true,
          ),
        ],
      ),
    );
  }
}

class _PanelLateral extends StatelessWidget {
  final String titulo;
  final Widget child;

  const _PanelLateral({super.key, required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _FaseNegocio extends StatelessWidget {
  final String texto;
  final bool completada;
  final bool actual;
  final bool mostrarLinea;

  const _FaseNegocio({
    required this.texto,
    this.completada = false,
    this.actual = false,
    this.mostrarLinea = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = completada || actual ? AppColors.blueLt : AppColors.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: actual ? AppColors.blue : AppColors.fondo,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(
                  completada ? Icons.check : Icons.circle,
                  size: completada ? 14 : 7,
                  color: color,
                ),
              ),
              if (mostrarLinea)
                Container(width: 1.5, height: 34, color: AppColors.border),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              texto,
              style: TextStyle(
                color: actual
                    ? AppColors.texto
                    : AppColors.texto.withValues(alpha: 0.72),
                fontSize: 13,
                height: 1.35,
                fontWeight: actual ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AyudaProducto extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final bool ultimo;

  const _AyudaProducto({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.ultimo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.blueLt.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icono, size: 17, color: AppColors.blueLt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: TextStyle(
                    color: AppColors.texto.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
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
