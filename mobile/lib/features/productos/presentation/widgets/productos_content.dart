// ═════════════════════════════════════════════════════════════════════════
// ProductosContent
// ═════════════════════════════════════════════════════════════════════════
// Contenido puro del listado de productos. Se embebe dentro de un
// ProductosScreen (o de un contenedor futuro del dashboard) que ya provee
// el Scaffold, SafeArea y los providers.
//
// QUÉ HACE:
// - Dibuja encabezado, lista o cuadrícula, estados (carga/vacío/error),
//   paginación manual ("Ver más") y acciones de tarjeta/agregar.
// - Consume ProductosProvider y CatalogoNegocioProvider del árbol
//   (context.watch) y decide el reparto móvil/escritorio con LayoutBuilder
//   usando el ancho LOCAL disponible (no el ancho global de la ventana).
//
// QUÉ NO HACE:
// - NO crea Scaffold, AppBar, SafeArea, Navigator ni providers.
// - NO toca repositorios, Firestore ni Cloudinary.
// - Las acciones que requieren navegación o diálogos se delegan vía
//   callbacks (onAgregar, onEditar, onEliminar, onElegirPlantilla) que el
//   embebedor implementa.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../negocio/presentation/providers/catalogo_negocio_provider.dart';
import '../../domain/models/producto.dart';
import '../providers/productos_provider.dart';
import 'producto_card.dart';
import 'productos_contextual_panel.dart';

class ProductosContent extends StatelessWidget {
  final bool mostrarGuiaConfiguracion;
  final bool mostrarPanelesLaterales;
  final VoidCallback? onAgregar;
  final ValueChanged<Producto>? onEditar;
  final ValueChanged<String>? onEliminar;
  final VoidCallback? onElegirPlantilla;

  const ProductosContent({
    super.key,
    this.mostrarGuiaConfiguracion = true,
    this.mostrarPanelesLaterales = true,
    this.onAgregar,
    this.onEditar,
    this.onEliminar,
    this.onElegirPlantilla,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esDesktop = constraints.maxWidth >= 1100;
        final provider = context.watch<ProductosProvider>();
        final catalogoProvider = context.watch<CatalogoNegocioProvider>();
        final productos = provider.productosFiltrados;
        return esDesktop
            ? _construirDesktop(context, provider, catalogoProvider, productos)
            : _construirMovil(context, provider, catalogoProvider, productos);
      },
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
                              onElegirPlantilla: onElegirPlantilla,
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
    final contenidoCentral = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EncabezadoProductos(
            agregarHabilitado: agregarHabilitado,
            onAgregar: () => onAgregar?.call(),
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnas,
                    mainAxisExtent: alturaTarjeta,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) => _construirProductoCard(
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
                onElegirPlantilla: onElegirPlantilla,
              ),
            ],
          ],
        ],
      ),
    );
    return SingleChildScrollView(
      key: const Key('productos-page-scroll'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1680),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mostrarPanelesLaterales && mostrarGuiaConfiguracion) ...[
                const SizedBox(width: 196, child: FasesNegocioPanel()),
                const SizedBox(width: 18),
              ],
              contenidoCentral,
              if (mostrarPanelesLaterales) ...[
                const SizedBox(width: 18),
                const SizedBox(width: 224, child: ProductosContextualPanel()),
              ],
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
          ? () => onEditar?.call(producto)
          : null,
      onEliminar: accionesHabilitadas
          ? () => onEliminar?.call(producto.id)
          : null,
      onToggleDisponible: accionesHabilitadas
          ? () => provider.toggleDisponible(producto.id, !producto.disponible)
          : null,
    );
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
  final VoidCallback? onElegirPlantilla;

  const _BotonElegirPlantilla({
    required this.catalogoProvider,
    required this.onElegirPlantilla,
  });

  @override
  Widget build(BuildContext context) {
    final catalogo = catalogoProvider.catalogo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: FilledButton.icon(
          onPressed: catalogo == null ? null : onElegirPlantilla,
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
