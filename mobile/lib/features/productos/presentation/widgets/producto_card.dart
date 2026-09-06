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
  final Producto producto;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onToggleDisponible;

  const ProductoCard({
    super.key,
    required this.producto,
    required this.onEditar,
    required this.onEliminar,
    required this.onToggleDisponible,
  });

  @override
  Widget build(BuildContext context) {
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
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_outlined,
                          color: AppColors.border,
                        ),
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
                            color: AppColors.blueLt,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(' · ', style: TextStyle(color: AppColors.muted)),
                        Text(
                          producto.esStockInfinito ? '∞' : '${producto.stock} uds.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        if (producto.categoria.isNotEmpty) ...[
                          Text(' · ', style: TextStyle(color: AppColors.muted)),
                          Expanded(
                            child: Text(
                              producto.categoria,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Acciones ────────────────────────────────────────
              IconButton(
                onPressed: onToggleDisponible,
                icon: Icon(
                  producto.disponible ? Icons.check_circle : Icons.cancel,
                  color: producto.disponible ? Colors.green : AppColors.error,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: onEditar,
                icon: Icon(Icons.edit_outlined, color: AppColors.muted, size: 18),
              ),
              IconButton(
                onPressed: onEliminar,
                icon: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              ),
            ],
          ),
          if (producto.unidadMedidaNombre.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(color: AppColors.border, height: 0.5),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.straighten, size: 12, color: AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  producto.fraccionesSeleccionadas.isNotEmpty
                      ? '${producto.unidadMedidaNombre} · fracción: ${producto.fraccionesSeleccionadas.first}'
                      : producto.unidadMedidaNombre,
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}