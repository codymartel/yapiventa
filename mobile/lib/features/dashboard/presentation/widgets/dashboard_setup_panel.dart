import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';

class DashboardSetupPanel extends StatelessWidget {
  final ProgresoConfiguracion progreso;
  final ValueChanged<EtapaConfiguracion> onAbrirEtapa;

  const DashboardSetupPanel({
    super.key,
    required this.progreso,
    required this.onAbrirEtapa,
  });

  static const _etapas = [
    (EtapaConfiguracion.rubro, 'Rubro'),
    (EtapaConfiguracion.negocio, 'Configurar negocio'),
    (EtapaConfiguracion.productos, 'Agregar productos'),
    (EtapaConfiguracion.plantilla, 'Plantilla web'),
  ];

  @override
  Widget build(BuildContext context) {
    if (progreso.completo) return const SizedBox.shrink();
    return Container(
      key: const Key('dashboard-setup-panel'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Completa la configuración',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cada etapa usa la información confirmada en la anterior.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 820;
              final items = _etapas
                  .map(
                    (etapa) => _EtapaItem(
                      etapa: etapa.$1,
                      titulo: etapa.$2,
                      progreso: progreso,
                      onAbrir: onAbrirEtapa,
                    ),
                  )
                  .toList();
              return horizontal
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: items
                          .map((item) => Expanded(child: item))
                          .toList(),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: item,
                            ),
                          )
                          .toList(),
                    );
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('continuar-configuracion'),
            onPressed: () => onAbrirEtapa(progreso.siguiente),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuar configuración'),
          ),
        ],
      ),
    );
  }
}

class _EtapaItem extends StatelessWidget {
  final EtapaConfiguracion etapa;
  final String titulo;
  final ProgresoConfiguracion progreso;
  final ValueChanged<EtapaConfiguracion> onAbrir;

  const _EtapaItem({
    required this.etapa,
    required this.titulo,
    required this.progreso,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final completa = _completa;
    final siguiente = progreso.siguiente == etapa;
    final bloqueada = !completa && !siguiente;
    final color = completa
        ? Colors.greenAccent.shade400
        : siguiente
        ? AppColors.blueLt
        : AppColors.muted;
    return InkWell(
      onTap: completa ? () => onAbrir(etapa) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              completa
                  ? Icons.check_circle
                  : siguiente
                  ? Icons.radio_button_checked
                  : Icons.lock_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    completa
                        ? 'Completado. Puedes revisarlo.'
                        : siguiente
                        ? 'Siguiente etapa pendiente.'
                        : _requisito,
                    style: TextStyle(color: color, fontSize: 11),
                  ),
                  if (bloqueada) const SizedBox(height: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _completa => switch (etapa) {
    EtapaConfiguracion.rubro => progreso.rubroCompleto,
    EtapaConfiguracion.negocio => progreso.negocioCompleto,
    EtapaConfiguracion.productos => progreso.productosCompletos,
    EtapaConfiguracion.plantilla => progreso.plantillaCompleta,
    EtapaConfiguracion.completa => progreso.completo,
  };

  String get _requisito => switch (etapa) {
    EtapaConfiguracion.rubro => 'Selecciona primero un rubro válido.',
    EtapaConfiguracion.negocio => 'Requiere un rubro guardado.',
    EtapaConfiguracion.productos =>
      'Requiere la configuración obligatoria del negocio.',
    EtapaConfiguracion.plantilla => 'Requiere al menos un producto válido.',
    EtapaConfiguracion.completa => '',
  };
}
