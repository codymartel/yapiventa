import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/encabezado_pantalla.dart';
import '../providers/configuracion_negocio_provider.dart';
import 'paso_negocio.dart';
import 'paso_catalogo.dart';
import 'paso_logistica.dart';
import 'paso_pagos.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfiguracionNegocioContent
// ═════════════════════════════════════════════════════════════════════════
// Contenido puro del wizard de 4 pasos. Arma el stepper (barra de progreso +
// tabs de pasos), muestra el widget del paso actual, y los botones de
// navegación Atrás/Siguiente/Finalizar.
//
// REGLAS DE ESTE WIDGET:
// - NO crea Scaffold, AppBar ni SafeArea (los provee quien lo embebe).
// - NO crea providers — consume el ConfiguracionNegocioProvider que ya
//   existe más arriba (los cuatro pasos dependen de él).
// - NO usa Navigator directamente ni accede a repositorios/Firestore:
//   toda la navegación y el guardado se delegan vía onVolver/onFinalizar.
// ═════════════════════════════════════════════════════════════════════════

class ConfiguracionNegocioContent extends StatelessWidget {
  /// Identidad del usuario dueño del negocio. La necesita el paso Catálogo
  /// para las escrituras de categorías, que persisten por (uid, negocioId).
  final String uid;

  final String rubro;
  final VoidCallback onVolver;
  final VoidCallback onFinalizar;

  const ConfiguracionNegocioContent({
    super.key,
    required this.uid,
    required this.rubro,
    required this.onVolver,
    required this.onFinalizar,
  });

  static const _nombresPasos = ['Negocio', 'Catálogo', 'Logística', 'Pagos'];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 720;
        final paddingHorizontal = compacto ? 12.0 : 20.0;
        return Column(
          children: [
            // ── HEADER compacto: volver + título, y el stepper justo debajo ─
            // Sin subtítulo ni padding propio del encabezado: el ritmo vertical
            // va aquí para que la cabecera ocupe lo mínimo antes del contenido.
            Container(
              width: double.infinity,
              color: AppColors.superficie,
              padding: EdgeInsets.fromLTRB(
                paddingHorizontal,
                8,
                paddingHorizontal,
                10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Cambiar rubro',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: p.guardando ? null : onVolver,
                        icon: const Icon(Icons.arrow_back, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: EncabezadoPantalla.sinPadding(
                          titulo: 'Configura tu $rubro',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _BarraPasos(
                    pasoActual: p.pasoActual,
                    nombres: _nombresPasos,
                    onPasoClick: (i) {
                      if (i < p.pasoActual) p.irAPaso(i);
                    },
                  ),
                ],
              ),
            ),

            // ── CONTENIDO del paso actual ───────────────────────────────
            Expanded(
              child: IndexedStack(
                index: p.pasoActual,
                children: [
                  const PasoNegocio(),
                  PasoCatalogo(uid: uid),
                  const PasoLogistica(),
                  const PasoPagos(),
                ],
              ),
            ),

            // ── NAVEGACIÓN entre pasos ───────────────────────────────────
            // Vive en el flujo de la columna, nunca superpuesto: no puede
            // tapar el contenido del paso.
            Container(
              width: double.infinity,
              color: AppColors.fondo,
              padding: EdgeInsets.fromLTRB(
                paddingHorizontal,
                10,
                paddingHorizontal,
                10,
              ),
              child: Row(
                children: [
                  if (p.pasoActual > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: p.guardando ? null : p.atras,
                        style: _estiloBotonNavegacion(),
                        child: const Text('Atrás'),
                      ),
                    ),
                  if (p.pasoActual > 0) const SizedBox(width: 10),
                  if (p.pasoActual == 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: p.guardando ? null : onVolver,
                        style: _estiloBotonNavegacion(),
                        child: const Text('Cambiar rubro'),
                      ),
                    ),
                  if (p.pasoActual == 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.dim,
                        disabledForegroundColor: AppColors.muted,
                      ),
                      onPressed: !p.puedeAvanzarActual || p.guardando
                          ? null
                          : () {
                              if (p.pasoActual <
                                  ConfiguracionNegocioProvider.totalPasos -
                                      1) {
                                p.siguiente();
                                return;
                              }
                              onFinalizar();
                            },
                      child: p.guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              p.pasoActual <
                                      ConfiguracionNegocioProvider.totalPasos -
                                          1
                                  ? 'Siguiente'
                                  : 'Finalizar',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  ButtonStyle _estiloBotonNavegacion() => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

/// Stepper del wizard en una sola línea: badge numerado + label por paso.
///
/// El paso activo se marca con badge relleno, label en azul y un fondo tenue;
/// los pasos ya completados quedan en azul claro y los pendientes apagados.
class _BarraPasos extends StatelessWidget {
  final int pasoActual;
  final List<String> nombres;
  final void Function(int) onPasoClick;

  const _BarraPasos({
    required this.pasoActual,
    required this.nombres,
    required this.onPasoClick,
  });

  @override
  Widget build(BuildContext context) {
    final progreso = (pasoActual + 1) / nombres.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 2,
            backgroundColor: AppColors.border,
            color: AppColors.blueLt,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (var i = 0; i < nombres.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPasoClick(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: i == pasoActual
                          ? AppColors.blue.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BadgePaso(
                          numero: i + 1,
                          activo: i == pasoActual,
                          completado: i < pasoActual,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            nombres[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.screenSubtitle.copyWith(
                              fontSize: 9.5,
                              height: 1.2,
                              fontWeight: i == pasoActual
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == pasoActual
                                  ? AppColors.texto
                                  : (i < pasoActual
                                        ? AppColors.blueLt
                                        : AppColors.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Círculo numerado del stepper. Relleno en el paso activo, contorno en el resto.
class _BadgePaso extends StatelessWidget {
  final int numero;
  final bool activo;
  final bool completado;

  const _BadgePaso({
    required this.numero,
    required this.activo,
    required this.completado,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo
        ? AppColors.blueLt
        : (completado ? AppColors.blueLt : AppColors.muted);
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: activo ? AppColors.blueLt : Colors.transparent,
        border: Border.all(
          color: activo || completado ? AppColors.blueLt : AppColors.dim,
          width: 1,
        ),
      ),
      child: Text(
        '$numero',
        style: AppTypography.screenEyebrow.copyWith(
          fontSize: 9.5,
          height: 1,
          letterSpacing: 0,
          color: activo ? Colors.white : color,
        ),
      ),
    );
  }
}
