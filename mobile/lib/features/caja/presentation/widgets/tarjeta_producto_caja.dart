import 'package:flutter/material.dart';
import 'package:mobile/features/productos/application/services/portada_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/widgets/mosaico_fotos.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/disponibilidad_caja.dart';
import '../../application/services/textos_producto_caja.dart';

/// Un producto de la lista de Caja (maqueta B1): foto, nombre, tipo y stock a
/// la izquierda, precio a la derecha. Un toque lo elige. Sin stock se ve
/// apagado (sigue tocable: la hoja del producto lo explica). Sin stock bajo en
/// color solo: siempre con texto («Quedan 3»).
class TarjetaProductoCaja extends StatelessWidget {
  const TarjetaProductoCaja({
    super.key,
    required this.producto,
    required this.onElegir,
  });

  final Producto producto;
  final ValueChanged<Producto> onElegir;

  @override
  Widget build(BuildContext context) {
    final sinStock = !DisponibilidadCaja.tieneStock(producto);
    final bajo = DisponibilidadCaja.stockBajo(producto);
    final tipo = TextosProductoCaja.tipo(producto);
    // Un combo no tiene stock propio y la lista no trae sus partes: no se
    // muestra un número que no es (el cobro comprueba el stock real).
    final stock = producto.esCombo
        ? ''
        : sinStock
        ? 'Sin stock'
        : bajo
        ? 'Quedan ${producto.stock}'
        : 'Stock ${TextosProductoCaja.stock(producto)}';

    return Opacity(
      opacity: sinStock ? 0.55 : 1,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onElegir(producto),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bordeSutil),
            ),
            child: Row(
              children: [
                _Foto(producto: producto),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (tipo.isNotEmpty && stock.isNotEmpty)
                              TextSpan(text: '$tipo · ')
                            else if (tipo.isNotEmpty)
                              TextSpan(text: tipo),
                            TextSpan(
                              text: stock,
                              style: TextStyle(
                                color: bajo ? AppColors.aviso : null,
                                fontWeight: bajo ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    TextosProductoCaja.precio(producto),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.azulTexto,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final url = producto.urlImagen.isNotEmpty
        ? producto.urlImagen
        : (PortadaProducto.deModelos(producto.modelos)?.urlImagen ?? '');
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dim),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              semanticLabel: 'Foto de ${producto.nombre}',
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_outlined,
                size: 20,
                color: AppColors.hint,
              ),
            )
          : producto.esCombo
          ? MosaicoFotos(urls: [for (final p in producto.partes) p.urlImagen])
          : const Icon(Icons.image_outlined, size: 20, color: AppColors.hint),
    );
  }
}
