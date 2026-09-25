import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/configuracion_negocio_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// SeccionResumenCatalogo — Resumen "antes de avanzar" del paso Catálogo
// ═════════════════════════════════════════════════════════════════════════
// Tarjeta de solo lectura con el estado actual del borrador del catálogo:
// categorías activas, presentaciones activas, medidas activas, formatos
// configurados, cantidades rápidas y errores pendientes (medidas por
// revisar). Vive al final del ListView del paso, así que comparte el mismo
// scroll y nunca queda detrás de la barra de navegación del wizard.
//
// NO escribe Firestore ni modifica el proveedor: solo lee sus getters.
// ═════════════════════════════════════════════════════════════════════════

class SeccionResumenCatalogo extends StatelessWidget {
  const SeccionResumenCatalogo({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    final pendientes = p.medidasPendientesRevision;

    return Container(
      key: const Key('seccion-resumen-catalogo'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: AppColors.blueLt, size: 20),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Resumen del catálogo',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Antes de continuar, revisa tu catálogo.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final dosColumnas = constraints.maxWidth >= 640;
              final ancho = dosColumnas
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: ancho,
                    child: _FilaResumen(
                      clave: 'resumen-categorias',
                      etiqueta: 'Categorías activas',
                      valor: '${p.categoriasActivas}',
                    ),
                  ),
                  SizedBox(
                    width: ancho,
                    child: _FilaResumen(
                      clave: 'resumen-presentaciones',
                      etiqueta: 'Presentaciones activas',
                      valor: '${p.presentacionesActivas}',
                    ),
                  ),
                  SizedBox(
                    width: ancho,
                    child: _FilaResumen(
                      clave: 'resumen-medidas',
                      etiqueta: 'Medidas activas',
                      valor: '${p.medidasActivas}',
                    ),
                  ),
                  SizedBox(
                    width: ancho,
                    child: _FilaResumen(
                      clave: 'resumen-formatos',
                      etiqueta: 'Formatos configurados',
                      valor: '${p.totalFormatos}',
                    ),
                  ),
                  SizedBox(
                    width: ancho,
                    child: _FilaResumen(
                      clave: 'resumen-cantidades-rapidas',
                      etiqueta: 'Cantidades rápidas',
                      valor: '${p.totalCantidadesRapidas}',
                    ),
                  ),
                  SizedBox(
                    width: ancho,
                    child: _FilaErrores(
                      clave: 'resumen-errores',
                      etiqueta: 'Errores pendientes',
                      pendientes: pendientes,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  final String clave;
  final String etiqueta;
  final String valor;

  const _FilaResumen({
    required this.clave,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(clave),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            valor,
            key: Key('$clave-valor'),
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaErrores extends StatelessWidget {
  final String clave;
  final String etiqueta;
  final List<String> pendientes;

  const _FilaErrores({
    required this.clave,
    required this.etiqueta,
    required this.pendientes,
  });

  @override
  Widget build(BuildContext context) {
    final valor = pendientes.isEmpty
        ? const Text(
            'Ninguno',
            key: Key('resumen-errores-valor'),
            style: TextStyle(
              color: AppColors.blueLt,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          )
        : Text(
            'Medidas pendientes de revisión: ${pendientes.join(', ')}.',
            key: Key('$clave-valor'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
    return Container(
      key: Key(clave),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: pendientes.isEmpty ? AppColors.border : AppColors.error,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: valor),
        ],
      ),
    );
  }
}