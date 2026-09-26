import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Encabezado único de pantalla para todos los módulos del [AuthenticatedShell].
///
/// Unifica la jerarquía visual: antetítulo opcional → título → subtítulo, con
/// las acciones a la derecha del título cuando hay sitio y apiladas cuando no.
/// Todo el ritmo vertical sale de aquí, así que los módulos no vuelven a
/// inventar `fontSize` ni gaps.
///
/// No crea Scaffold ni providers, no lee repositorios y no navega.
class EncabezadoPantalla extends StatelessWidget {
  /// Antetítulo en versalitas. Opcional.
  final String? eyebrow;

  /// Título principal de la pantalla.
  final String titulo;

  /// Explicación breve bajo el título. Opcional.
  final String? subtitulo;

  /// Acciones a la derecha del título (CTA, selector de periodo…).
  final Widget? acciones;

  /// Contenido auxiliar que va debajo del subtítulo (stepper, filtros).
  final Widget? debajo;

  /// Paleta. Por defecto la de la app; los módulos de onboarding, que viven
  /// sobre su propio fondo, sobreescriben solo estos tres colores.
  final Color? colorEyebrow;
  final Color? colorTitulo;
  final Color? colorSubtitulo;

  final EdgeInsets padding;

  const EncabezadoPantalla({
    super.key,
    this.eyebrow,
    required this.titulo,
    this.subtitulo,
    this.acciones,
    this.debajo,
    this.colorEyebrow,
    this.colorTitulo,
    this.colorSubtitulo,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
  });

  /// Variante para pantallas que ya viven dentro de un contenedor con su propio
  /// padding horizontal (Productos desktop/móvil ya lo aplican).
  const EncabezadoPantalla.sinPadding({
    super.key,
    this.eyebrow,
    required this.titulo,
    this.subtitulo,
    this.acciones,
    this.debajo,
    this.colorEyebrow,
    this.colorTitulo,
    this.colorSubtitulo,
  }) : padding = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.screenEyebrow.copyWith(
              color: colorEyebrow ?? AppColors.blueLt,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.screenTitle.copyWith(
            color: colorTitulo ?? AppColors.texto,
          ),
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitulo!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.screenSubtitle.copyWith(
              color: colorSubtitulo ?? AppColors.muted,
            ),
          ),
        ],
      ],
    );

    final contenido = acciones == null
        ? textos
        : LayoutBuilder(
            builder: (context, constraints) {
              // Por debajo de este ancho el CTA no cabe a la derecha del
              // título: se apila bajo el subtítulo en vez de desbordar.
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    textos,
                    const SizedBox(height: 10),
                    acciones!,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: textos),
                  const SizedBox(width: 16),
                  // Flexible también la acción: con texto muy ampliado una
                  // etiqueta larga cede espacio en vez de desbordar la fila.
                  Flexible(child: acciones!),
                ],
              );
            },
          );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          contenido,
          if (debajo != null) ...[const SizedBox(height: 10), debajo!],
        ],
      ),
    );
  }
}
