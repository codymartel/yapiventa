import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';

/// Contraste WCAG entre dos colores (1:1 a 21:1).
double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  const fondos = {
    'fondo': AppColors.fondo,
    'superficie': AppColors.superficie,
    'card': AppColors.card,
  };
  const textos = {
    'texto': AppColors.texto,
    'muted': AppColors.muted,
    'hint': AppColors.hint,
    'azulTexto': AppColors.azulTexto,
    'error': AppColors.error,
    'ok': AppColors.ok,
    'aviso': AppColors.aviso,
  };

  group('Los colores de texto se leen (mínimo 4,5:1)', () {
    for (final texto in textos.entries) {
      for (final fondo in fondos.entries) {
        test('${texto.key} sobre ${fondo.key}', () {
          expect(
            _contraste(texto.value, fondo.value),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }
  });

  test('texto blanco sobre el botón azul se lee', () {
    expect(_contraste(Colors.white, AppColors.blue), greaterThanOrEqualTo(4.5));
  });

  test('dim no sirve como texto: queda solo para bordes y rellenos', () {
    expect(_contraste(AppColors.dim, AppColors.fondo), lessThan(3));
  });
}
