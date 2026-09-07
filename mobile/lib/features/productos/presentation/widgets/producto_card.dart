import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// ProductoCard
// ═════════════════════════════════════════════════════════════════════════
// Migración de tu @Composable ProductoCard. Solo dibuja — no sabe nada
// de Firestore, recibe callbacks (onEditar, onEliminar, onToggleDisponible)
// que la pantalla conecta al provider.
// ═════════════════════════════════════════════════════════════════════════

class ProductoCard extends StatelessWidget {
  static const _textoSecundario = Color(0xFFAFBDD3);
  static const _precio = Color(0xFF8AB2FF);
  static const _disponible = Color(0xFF72D993);
  static const _noDisponible = Color(0xFFFF7B7B);

  final Producto producto;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;
  final VoidCallback? onToggleDisponible;
  final bool esCuadricula;
  final bool cambiandoDisponibilidad;

  const ProductoCard({
    super.key,
    required this.producto,
    required this.onEditar,
    required this.onEliminar,
    required this.onToggleDisponible,
    this.esCuadricula = false,
    this.cambiandoDisponibilidad = false,
  });

  @override
  Widget build(BuildContext context) {
    return esCuadricula ? _construirCuadricula() : _construirLista();
  }

  Widget _construirLista() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Miniatura ────────────────────────────────────────
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: producto.urlImagen.isNotEmpty
                    ? Image.network(
                        producto.urlImagen,
                        fit: BoxFit.cover,
                        semanticLabel: 'Imagen de ${producto.nombre}',
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.image_outlined, color: AppColors.border),
                      )
                    : Icon(Icons.image_outlined, color: AppColors.border),
              ),
              const SizedBox(width: 12),

              // ── Datos principales ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'S/ ${producto.precio.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _precio,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(' · ', style: TextStyle(color: _textoSecundario)),
                        Text(
                          producto.esStockInfinito
                              ? '∞'
                              : '${producto.stock} uds.',
                          style: TextStyle(
                            color: _textoSecundario,
                            fontSize: 12,
                          ),
                        ),
                        if (producto.categoria.isNotEmpty) ...[
                          Text(
                            ' · ',
                            style: TextStyle(color: _textoSecundario),
                          ),
                          Expanded(
                            child: Text(
                              producto.categoria,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textoSecundario,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (producto.unidadMedidaNombre.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(color: AppColors.border, height: 0.5),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.straighten, size: 12, color: _textoSecundario),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    producto.fraccionesSeleccionadas.isNotEmpty
                        ? '${producto.unidadMedidaNombre} · fracción: ${producto.fraccionesSeleccionadas.first}'
                        : producto.unidadMedidaNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textoSecundario, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Divider(color: AppColors.border, height: 1),
          _acciones(),
        ],
      ),
    );
  }

  Widget _construirCuadricula() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 128,
            child: ColoredBox(
              color: AppColors.fondo,
              child: producto.urlImagen.isNotEmpty
                  ? Image.network(
                      producto.urlImagen,
                      fit: BoxFit.cover,
                      semanticLabel: 'Imagen de ${producto.nombre}',
                      errorBuilder: (_, _, _) => _imagenVacia(),
                    )
                  : _imagenVacia(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'S/ ${producto.precio.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _precio,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DatoProducto(
                    icono: Icons.inventory_2_outlined,
                    texto: _stockYUnidad(),
                  ),
                  const SizedBox(height: 6),
                  _DatoProducto(
                    icono: Icons.sell_outlined,
                    texto: producto.categoria.isEmpty
                        ? 'Sin categoría'
                        : producto.categoria,
                  ),
                  const Spacer(),
                  _EstadoProducto(disponible: producto.disponible),
                ],
              ),
            ),
          ),
          Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: _acciones(usarIconoVisibilidad: true),
          ),
        ],
      ),
    );
  }

  Widget _imagenVacia() {
    return Center(
      child: Icon(Icons.image_outlined, color: AppColors.dim, size: 38),
    );
  }

  String _stockYUnidad() {
    final stock = producto.esStockInfinito
        ? 'Stock ilimitado'
        : 'Stock: ${producto.stock}';
    if (producto.unidadMedidaNombre.isEmpty) return stock;
    return '$stock · ${producto.unidadMedidaNombre}';
  }

  Widget _acciones({bool usarIconoVisibilidad = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: cambiandoDisponibilidad
              ? 'Actualizando disponibilidad'
              : producto.disponible
              ? 'Marcar como no disponible'
              : 'Marcar como disponible',
          onPressed: onToggleDisponible,
          icon: cambiandoDisponibilidad
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  usarIconoVisibilidad
                      ? producto.disponible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined
                      : producto.disponible
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: producto.disponible
                      ? _disponible
                      : usarIconoVisibilidad
                      ? _textoSecundario
                      : _noDisponible,
                  size: 20,
                ),
        ),
        IconButton(
          tooltip: 'Editar producto',
          onPressed: onEditar,
          icon: Icon(Icons.edit_outlined, color: _textoSecundario, size: 20),
        ),
        IconButton(
          tooltip: 'Eliminar producto',
          onPressed: onEliminar,
          icon: Icon(Icons.delete_outline, color: _noDisponible, size: 20),
        ),
      ],
    );
  }
}

class _DatoProducto extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _DatoProducto({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 15, color: ProductoCard._textoSecundario),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ProductoCard._textoSecundario,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _EstadoProducto extends StatelessWidget {
  final bool disponible;

  const _EstadoProducto({required this.disponible});

  @override
  Widget build(BuildContext context) {
    final color = disponible
        ? ProductoCard._disponible
        : ProductoCard._noDisponible;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        disponible ? 'Disponible' : 'No disponible',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
