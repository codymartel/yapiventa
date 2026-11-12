import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

// ═════════════════════════════════════════════════════════════════════════
// Piezas compartidas de las hojas de Caja
// ═════════════════════════════════════════════════════════════════════════
// Lo que se repite en la venta y en el gasto: el título de sección, el aviso
// en ámbar y el campo de texto. Un solo diseño para todos.
// ═════════════════════════════════════════════════════════════════════════

/// El título pequeño de una sección dentro de una hoja de Caja.
class TituloSeccionCaja extends StatelessWidget {
  const TituloSeccionCaja(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Un aviso corto en ámbar, con icono y texto (nunca solo color).
class AvisoCaja extends StatelessWidget {
  const AvisoCaja(this.texto, {super.key, this.error = false});

  final String texto;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.error : AppColors.aviso;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Un campo de texto de Caja: etiqueta SIEMPRE visible arriba (no solo el
/// texto de ejemplo), 48 px de alto y borde azul al escribir. Al enfocarse,
/// el deslizable que lo contiene lo lleva a la vista sobre el teclado.
class CampoCaja extends StatelessWidget {
  const CampoCaja({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.onChanged,
    this.ejemplo = '',
    this.teclado = TextInputType.text,
    this.maximo,
    this.formatos,
    this.accion = TextInputAction.next,
    this.lineas = 1,
  });

  final String etiqueta;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String ejemplo;
  final TextInputType teclado;
  final int? maximo;
  final List<TextInputFormatter>? formatos;
  final TextInputAction accion;
  final int lineas;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color, [double ancho = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: ancho),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: teclado,
          textInputAction: accion,
          inputFormatters: [
            if (maximo != null) LengthLimitingTextInputFormatter(maximo),
            ...?formatos,
          ],
          minLines: 1,
          maxLines: lineas,
          // Deja aire bajo el campo al llevarlo a la vista sobre el teclado.
          scrollPadding: const EdgeInsets.only(bottom: 96),
          style: const TextStyle(color: AppColors.texto, fontSize: 15),
          decoration: InputDecoration(
            hintText: ejemplo,
            hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
            isDense: true,
            constraints: const BoxConstraints(minHeight: 48),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            enabledBorder: borde(AppColors.hint),
            focusedBorder: borde(AppColors.blueLt, 2),
          ),
        ),
      ],
    );
  }
}
