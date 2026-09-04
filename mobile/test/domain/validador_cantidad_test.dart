import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/validador_cantidad.dart';

void main() {
  group('ValidadorCantidad.validar — decimales', () {
    test('acepta enteros y hasta dos decimales', () {
      expect(ValidadorCantidad.validar('1000').valorDecimal, 1000);
      expect(ValidadorCantidad.validar('0.5').valorDecimal, 0.5);
      expect(ValidadorCantidad.validar('1000.25').valorDecimal, 1000.25);
    });

    test('rechaza más de dos decimales, coma y valores no positivos', () {
      expect(ValidadorCantidad.validar('1.234').esValido, isFalse);
      expect(ValidadorCantidad.validar('1,5').esValido, isFalse);
      expect(ValidadorCantidad.validar('0').esValido, isFalse);
    });

    test('rechaza cadena vacía', () {
      expect(ValidadorCantidad.validar('   ').esValido, isFalse);
    });
  });

  group('ValidadorCantidad.validar — fracciones', () {
    test('acepta fracción simple y mixta', () {
      expect(ValidadorCantidad.validar('1/2').valorDecimal, 0.5);
      expect(ValidadorCantidad.validar('2 1/2').valorDecimal, 2.5);
    });

    test('rechaza denominador cero y numerador mayor al denominador', () {
      expect(ValidadorCantidad.validar('1/0').esValido, isFalse);
      expect(ValidadorCantidad.validar('1 5/2').esValido, isFalse);
    });

    test('rechaza formato de fracción inválido', () {
      expect(ValidadorCantidad.validar('1//2').esValido, isFalse);
      expect(ValidadorCantidad.validar('a/b').esValido, isFalse);
    });
  });

  group('ValidadorCantidad.formatearComoFraccion', () {
    test('usa fracciones conocidas, con y sin parte entera', () {
      expect(ValidadorCantidad.formatearComoFraccion(0.25), '1/4');
      expect(ValidadorCantidad.formatearComoFraccion(2.5), '2 1/2');
    });

    test('deja el decimal tal cual cuando no es una fracción conocida', () {
      expect(ValidadorCantidad.formatearComoFraccion(0.3), '0.3');
    });
  });
}
