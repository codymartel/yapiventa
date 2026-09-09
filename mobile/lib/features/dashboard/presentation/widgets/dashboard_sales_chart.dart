import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/dashboard_ui_state.dart';

class DashboardSalesChart extends StatelessWidget {
  final List<DashboardSalesPoint> puntos;

  const DashboardSalesChart({super.key, required this.puntos});

  @override
  Widget build(BuildContext context) {
    final maximo = puntos.fold<double>(
      1,
      (actual, punto) =>
          math.max(actual, math.max(punto.online, punto.fisicas)),
    );
    final totalOnline = puntos.fold<double>(
      0,
      (total, punto) => total + punto.online,
    );
    final totalFisico = puntos.fold<double>(
      0,
      (total, punto) => total + punto.fisicas,
    );

    return Container(
      height: 360,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ventas de los últimos 7 días',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Comparación por canal',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Leyenda(color: const Color(0xFF4E8BFF), texto: 'Online'),
                  const SizedBox(width: 14),
                  _Leyenda(color: const Color(0xFF35C59A), texto: 'Físico'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final anchoGrafico = math.max(320.0, constraints.maxWidth);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: anchoGrafico,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final punto in puntos)
                          Expanded(
                            child: _GrupoBarras(punto: punto, maximo: maximo),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TotalCanal(
                  etiqueta: 'Online',
                  valor: totalOnline,
                  color: const Color(0xFF4E8BFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TotalCanal(
                  etiqueta: 'Físico',
                  valor: totalFisico,
                  color: const Color(0xFF35C59A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrupoBarras extends StatelessWidget {
  final DashboardSalesPoint punto;
  final double maximo;

  const _GrupoBarras({required this.punto, required this.maximo});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${punto.label}: online S/ ${punto.online.toStringAsFixed(0)}, '
          'físico S/ ${punto.fisicas.toStringAsFixed(0)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Barra(
                    proporcion: punto.online / maximo,
                    color: const Color(0xFF4E8BFF),
                  ),
                  const SizedBox(width: 4),
                  _Barra(
                    proporcion: punto.fisicas / maximo,
                    color: const Color(0xFF35C59A),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                punto.label,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  final double proporcion;
  final Color color;

  const _Barra({required this.proporcion, required this.color});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: proporcion.clamp(0.06, 1),
      child: Container(
        width: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;

  const _Leyenda({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _TotalCanal extends StatelessWidget {
  final String etiqueta;
  final double valor;
  final Color color;

  const _TotalCanal({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
          Text(
            'S/ ${valor.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
