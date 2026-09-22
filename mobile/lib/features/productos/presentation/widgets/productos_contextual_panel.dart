import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ProductosContextualPanel extends StatelessWidget {
  const ProductosContextualPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.sizeOf(context).width < 600;
    return DecoratedBox(
      key: const Key('productos-contextual-panel'),
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
              '¿Cómo funciona?',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: movil ? 17 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            _AyudaProducto(
              icono: Icons.add_photo_alternate_outlined,
              titulo: 'Agregar producto',
              descripcion: 'Crea un producto con imagen, precio y stock.',
              movil: movil,
            ),
            _AyudaProducto(
              icono: Icons.edit_outlined,
              titulo: 'Editar',
              descripcion: 'Modifica sus datos.',
              movil: movil,
            ),
            _AyudaProducto(
              icono: Icons.visibility_outlined,
              titulo: 'Disponibilidad',
              descripcion: 'Activa o desactiva su publicación.',
              movil: movil,
            ),
            _AyudaProducto(
              icono: Icons.delete_outline,
              titulo: 'Eliminar',
              descripcion: 'Quita el producto del catálogo.',
              movil: movil,
              ultimo: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AyudaProducto extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final bool movil;
  final bool ultimo;

  const _AyudaProducto({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.movil,
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
                    fontSize: movil ? 14 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: TextStyle(
                    color: AppColors.texto.withValues(alpha: 0.72),
                    fontSize: movil ? 12.5 : 12,
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
