import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// El chip de elección de Caja: filtros rápidos, categorías de «Avanzados» y
/// opciones de la hoja del producto (color, extras, cantidades). Un solo
/// diseño para todos: borde y texto apagados, y al estar activo fondo azul
/// suave y borde azul. Siempre con texto (el color nunca es lo único).
class ChipCaja extends StatelessWidget {
  const ChipCaja({
    super.key,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    this.icono,
    this.marcarActivo = false,
    this.habilitado = true,
    this.altoMinimo = 40,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  /// Un icono antes del texto (por ejemplo, el de «Avanzados»).
  final IconData? icono;

  /// Pone una marca ✓ antes del texto cuando está activo.
  final bool marcarActivo;

  /// Apagado: se ve tenue y no responde.
  final bool habilitado;

  /// 40 px en los filtros; 44 px en la hoja del producto (zona de toque).
  final double altoMinimo;

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.azulTexto : AppColors.muted;
    return Semantics(
      button: true,
      selected: activo,
      enabled: habilitado,
      label: etiqueta,
      child: Opacity(
        opacity: habilitado ? 1 : 0.45,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: habilitado ? onTap : null,
          child: Container(
            constraints: BoxConstraints(minHeight: altoMinimo),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: activo ? AppColors.blueLt.withValues(alpha: 0.22) : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: activo ? AppColors.blueLt : AppColors.bordeMedio,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 16, color: color),
                  const SizedBox(width: 6),
                ] else if (marcarActivo && activo) ...[
                  const Icon(Icons.check, size: 16, color: AppColors.azulTexto),
                  const SizedBox(width: 6),
                ],
                Text(
                  etiqueta,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
