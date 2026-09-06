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
import '../../data/productos_repository.dart';
import '../providers/productos_provider.dart';
import '../widgets/producto_card.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  ProductosProvider? _provider;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _provider = ProductosProvider(uid: uid, repository: ProductosRepository())
      ..cargarProductos();
  }

  @override
  void dispose() {
    _provider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
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

    return ChangeNotifierProvider.value(
      value: provider,
      child: const _ContenidoProductos(),
    );
  }
}

class _ContenidoProductos extends StatelessWidget {
  const _ContenidoProductos();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductosProvider>();
    final productos = provider.productosFiltrados;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.superficie,
        foregroundColor: AppColors.texto,
        title: const Text('Productos'),
        actions: [
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
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
                        itemCount: productos.length + (provider.hayMas ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == productos.length) {
                            return _BotonVerMas(provider: provider);
                          }

                          final producto = productos[index];
                          return ProductoCard(
                            key: ValueKey(producto.id),
                            producto: producto,
                            onEditar: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'La edicion estara disponible pronto.',
                                  ),
                                ),
                              );
                            },
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
    );
  }

  Future<void> _confirmarEliminacion(
    BuildContext context,
    ProductosProvider provider,
    String productoId,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
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

  const _MensajeError({required this.mensaje, required this.onCerrar});

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
            tooltip: 'Cerrar mensaje',
            onPressed: onCerrar,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
