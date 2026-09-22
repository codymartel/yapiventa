import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class RubroContextualPanel extends StatelessWidget {
  const RubroContextualPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RubroCard(
          icono: Icons.storefront_outlined,
          titulo: '¿Qué es un rubro?',
          contenido:
              'Define la actividad principal de tu negocio y condiciona cómo '
              'se organiza tu tienda.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _RubroCard(
          icono: Icons.category_outlined,
          titulo: 'Adapta categorías y unidades',
          contenido:
              'Al elegir el rubro, las categorías y unidades de medida de tus '
              'productos se adaptan a tu giro.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _RubroCard(
          icono: Icons.store_mall_directory_outlined,
          titulo: 'Primer guardado',
          contenido:
              'Cuando guardes por primera vez se crea y vincula tu negocio con '
              'tu cuenta.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _RubroCard(
          icono: Icons.sync_alt_rounded,
          titulo: 'Cambiar el rubro',
          contenido:
              'Cambiarlo más adelante puede exigir que revises la '
              'configuración de tu negocio.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _RubroCard(
          icono: Icons.lock_outline,
          titulo: 'Qué desbloquea',
          contenido:
              'Después de guardar se habilita Configuración. Productos y '
              'Plantilla siguen bloqueados.',
          movil: movil,
        ),
      ],
    );
  }
}

class _RubroCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String contenido;
  final bool movil;

  const _RubroCard({
    required this.icono,
    required this.titulo,
    required this.contenido,
    required this.movil,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icono, color: AppColors.blueLt, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: movil ? 14 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contenido,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: movil ? 12 : 11,
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
