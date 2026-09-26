import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
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
  final String rubro;
  final VoidCallback onVolver;
  final VoidCallback onFinalizar;

  const ConfiguracionNegocioContent({
    super.key,
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
            // ── HEADER: título + barra de pasos ──────────────────────────
            Container(
              width: double.infinity,
              color: AppColors.superficie,
              padding: EdgeInsets.fromLTRB(
                paddingHorizontal,
                8,
                paddingHorizontal,
                8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      tooltip: 'Cambiar rubro',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      onPressed: p.guardando ? null : onVolver,
                      icon: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Configura tu $rubro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 18,
                            height: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Crea tu tienda virtual.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                ],
              ),
            ),

            // ── CONTENIDO del paso actual ───────────────────────────────
            Expanded(
              child: IndexedStack(
                index: p.pasoActual,
                children: const [
                  PasoNegocio(),
                  PasoCatalogo(),
                  PasoLogistica(),
                  PasoPagos(),
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
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 2,
            backgroundColor: AppColors.border,
            color: AppColors.blue,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < nombres.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPasoClick(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.1,
                          color: i == pasoActual
                              ? AppColors.texto
                              : (i < pasoActual
                                    ? AppColors.blueLt
                                    : AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        nombres[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.1,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
