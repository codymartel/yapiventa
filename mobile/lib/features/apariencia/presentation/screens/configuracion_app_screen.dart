import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/tamano_letra.dart';
import '../providers/apariencia_provider.dart';

/// «Configuración» del menú: cómo se ve la app en este equipo. Hoy solo el
/// tamaño de letra (el fondo claro se suma cuando exista el tema claro).
/// No lee ni escribe en Firebase.
class ConfiguracionAppScreen extends StatelessWidget {
  const ConfiguracionAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final apariencia = context.watch<AparienciaProvider>();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Configuración',
              style: AppTypography.screenTitle.copyWith(color: AppColors.texto),
            ),
            const SizedBox(height: 4),
            Text(
              'Cómo se ve la app en este equipo.',
              style: AppTypography.screenSubtitle.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tamaño de letra',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: AppFontSize.subtitulo,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tamano in TamanoLetra.values)
                  _OpcionTamano(
                    tamano: tamano,
                    elegido: tamano == apariencia.tamanoLetra,
                    alElegir: () => apariencia.cambiarTamanoLetra(tamano),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _Muestra(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Se guarda solo en este equipo. Si entras desde otro teléfono '
              'o computadora, allí puedes elegir otro tamaño.',
              style: TextStyle(
                color: AppColors.hint,
                fontSize: AppFontSize.chico,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionTamano extends StatelessWidget {
  const _OpcionTamano({
    required this.tamano,
    required this.elegido,
    required this.alElegir,
  });

  final TamanoLetra tamano;
  final bool elegido;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    // La muestra «Aa» crece con cada opción para que se entienda sin leer.
    final tamanoMuestra = 13.0 + TamanoLetra.values.indexOf(tamano) * 3;
    return Semantics(
      button: true,
      selected: elegido,
      label: 'Letra ${tamano.etiqueta}',
      excludeSemantics: true,
      child: Material(
        color: elegido
            ? AppColors.blue.withValues(alpha: 0.16)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: elegido ? AppColors.blueLt : AppColors.bordeMedio,
          ),
        ),
        child: InkWell(
          key: ValueKey('tamano-letra-${tamano.clave}'),
          borderRadius: BorderRadius.circular(10),
          onTap: alElegir,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 104,
              minHeight: AppSpacing.minTactil + 20,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aa',
                    style: TextStyle(
                      color: elegido ? AppColors.texto : AppColors.muted,
                      fontSize: tamanoMuestra,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    tamano.etiqueta,
                    style: TextStyle(
                      color: elegido ? AppColors.texto : AppColors.muted,
                      fontSize: AppFontSize.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un ejemplo real para ver el tamaño elegido antes de salir.
class _Muestra extends StatelessWidget {
  const _Muestra();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Así se verá',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: AppFontSize.subtitulo,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pedido de Rosa · 2 Inca Kola 1 L · S/ 12,00',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: AppFontSize.cuerpo,
            ),
          ),
        ],
      ),
    );
  }
}
