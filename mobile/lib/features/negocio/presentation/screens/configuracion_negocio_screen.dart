import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/configuracion_negocio_provider.dart';
import '../widgets/paso_negocio.dart';
import '../widgets/paso_catalogo.dart';
import '../widgets/paso_logistica.dart';
import '../widgets/paso_pagos.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfiguracionNegocioScreen
// ═════════════════════════════════════════════════════════════════════════
// Pantalla principal del wizard de 4 pasos, migración de
// ConfiguracionNegocioScreen.kt. Arma el stepper (barra de progreso +
// tabs de pasos), muestra el widget del paso actual, y los botones de
// navegación Atrás/Siguiente/Finalizar.
//
// IMPORTANTE: esta pantalla espera que YA exista un
// ConfiguracionNegocioProvider más arriba en el árbol de widgets — se
// crea en main.dart, envolviendo esta pantalla con ChangeNotifierProvider
// (ver onGenerateRoute de la ruta '/configurar-negocio').
// ═════════════════════════════════════════════════════════════════════════

class ConfiguracionNegocioScreen extends StatelessWidget {
  final String rubro;
  final VoidCallback onVolver;
  final VoidCallback onFinalizar;

  const ConfiguracionNegocioScreen({
    super.key,
    required this.rubro,
    required this.onVolver,
    required this.onFinalizar,
  });

  static const _nombresPasos = ['Negocio', 'Catálogo', 'Logística', 'Pagos'];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER: título + barra de pasos ──────────────────────
            Container(
              width: double.infinity,
              color: AppColors.superficie,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Cambiar rubro',
                    onPressed: onVolver,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configura tu $rubro',
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crea tu tienda virtual.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
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

            // ── CONTENIDO del paso actual ─────────────────────────────
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

            // ── NAVEGACIÓN entre pasos ────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (p.pasoActual > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: p.atras,
                        child: const Text('Atrás'),
                      ),
                    ),
                  if (p.pasoActual > 0) const SizedBox(width: 12),
                  if (p.pasoActual == 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onVolver,
                        child: const Text('Cambiar rubro'),
                      ),
                    ),
                  if (p.pasoActual == 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        disabledBackgroundColor: AppColors.border,
                      ),
                      onPressed: !p.puedeAvanzarActual || p.guardando
                          ? null
                          : () async {
                              if (p.pasoActual <
                                  ConfiguracionNegocioProvider.totalPasos - 1) {
                                p.siguiente();
                                return;
                              }
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) return;
                              final exito = await p.guardar(uid);
                              if (exito) onFinalizar();
                            },
                      child: p.guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
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
        ),
      ),
    );
  }
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
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 3,
            backgroundColor: AppColors.border,
            color: AppColors.blue,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < nombres.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onPasoClick(i),
                  child: Column(
                    children: [
                      Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: i == pasoActual
                              ? AppColors.texto
                              : (i < pasoActual
                                    ? AppColors.blueLt
                                    : AppColors.muted),
                        ),
                      ),
                      Text(
                        nombres[i],
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
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
