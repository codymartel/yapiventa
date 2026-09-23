import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Ayuda contextual de la fase de plantilla web.
///
/// Widget independiente: no crea providers, no consulta repositorios ni
/// Firebase, no navega y no abre URLs (la apertura de la tienda la hace el
/// embebedor). Su contenido describe solo hechos comprobables del flujo
/// actual (SeleccionPlantillaFlow + SeleccionPlantillaProvider + el
/// guardado en NegocioRepository), sin afirmar que seleccionar publica o
/// activa la web.
class PlantillaContextualPanel extends StatelessWidget {
  const PlantillaContextualPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.sizeOf(context).width < 600;
    return Column(
      key: const Key('plantilla-contextual-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlantillaCard(
          icono: Icons.touch_app,
          titulo: 'Al elegir una plantilla',
          contenido:
              'Seleccionar una tarjeta solo marca tu elección. '
              'La tienda no cambia hasta que guardas con Finalizar.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _PlantillaCard(
          icono: Icons.inventory_2_outlined,
          titulo: 'Productos y datos intactos',
          contenido:
              'Guardar la plantilla no modifica tus productos, precios, '
              'stock, categorías ni la configuración del negocio.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _PlantillaCard(
          icono: Icons.keyboard,
          titulo: 'Cómo seleccionar',
          contenido:
              'Toca o haz clic en la tarjeta que prefieras '
              '(también con Enter o Espacio). Finalizar se habilita al elegir.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _PlantillaCard(
          icono: Icons.save_outlined,
          titulo: 'Qué hace Finalizar',
          contenido:
              'Guarda la plantilla elegida y marca la configuración como '
              'completada. Al terminar regresas al inicio.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _PlantillaCard(
          icono: Icons.swap_horiz,
          titulo: 'Cambiar después',
          contenido:
              'Puedes volver a esta sección en cualquier momento y guardar '
              'otra plantilla.',
          movil: movil,
        ),
        const SizedBox(height: 12),
        _PlantillaCard(
          icono: Icons.open_in_new,
          titulo: 'Abrir la tienda',
          contenido:
              'El botón "Ver tienda web" abre tu tienda pública en una '
              'pestaña nueva. Solo funciona si ya guardaste una plantilla y '
              'tu negocio tiene dirección; si no, se muestra un aviso.',
          movil: movil,
        ),
      ],
    );
  }
}

class _PlantillaCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String contenido;
  final bool movil;

  const _PlantillaCard({
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
