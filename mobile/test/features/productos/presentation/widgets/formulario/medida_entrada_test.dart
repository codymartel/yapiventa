import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario/medida_entrada.dart';

void main() {
  group('textoAUnidadBase', () {
    test('"4,35" kg con factor 1000 da 4350 g exactos', () {
      final resultado = textoAUnidadBase('4,35', 1000, unidadBase: 'g');
      expect(resultado.esValida, isTrue);
      expect(resultado.base, 4350);
    });

    test('"1.5" acepta punto como separador', () {
      final resultado = textoAUnidadBase('1.5', 1000, unidadBase: 'g');
      expect(resultado.base, 1500);
    });

    test('trunca hacia abajo los decimales que no caben', () {
      // 0,0004 kg = 0,4 g: MENOR que 1 g, se rechaza con mensaje.
      final chico = textoAUnidadBase('0,0004', 1000, unidadBase: 'g');
      expect(chico.esValida, isFalse);
      expect(chico.error, contains('más pequeña que 1 g'));

      // 1,5678 kg -> 1567 g (el 8 se descarta).
      final truncado = textoAUnidadBase('1,5678', 1000, unidadBase: 'g');
      expect(truncado.esValida, isTrue);
      expect(truncado.base, 1567);
    });

    test('factor 10 (cm) admite un decimal', () {
      expect(textoAUnidadBase('2,5', 10, unidadBase: 'mm').base, 25);
      expect(textoAUnidadBase(',5', 10, unidadBase: 'mm').base, 5);
      // 0,05 cm = 0,5 mm: truncado da 0, se rechaza con mensaje.
      final chico = textoAUnidadBase('0,05', 10, unidadBase: 'mm');
      expect(chico.esValida, isFalse);
      expect(chico.error, contains('más pequeña que 1 mm'));
    });

    test('rechaza negativos y texto', () {
      for (final entrada in ['-1', 'abc', '1 2', '1,2,3', '--1', '']) {
        final resultado = textoAUnidadBase(entrada, 1000, unidadBase: 'g');
        expect(resultado.esValida, isFalse, reason: 'entrada: "$entrada"');
        expect(resultado.error, isNotNull);
      }
    });
  });

  group('baseATextoVisual', () {
    test('devuelve texto con coma y sin ceros de más', () {
      expect(baseATextoVisual(1500, 1000), '1,5');
      expect(baseATextoVisual(1000, 1000), '1');
      expect(baseATextoVisual(100, 1000), '0,1');
      expect(baseATextoVisual(1750, 1000), '1,75');
      expect(baseATextoVisual(250, 10), '25');
      expect(baseATextoVisual(25, 1), '25');
    });

    test('ida y vuelta texto -> base -> texto', () {
      for (final texto in ['1,5', '0,25', '3', '0,1']) {
        final base = textoAUnidadBase(texto, 1000, unidadBase: 'g').base!;
        expect(baseATextoVisual(base, 1000), texto);
      }
    });
  });

  group('precio', () {
    test('textoACentavos acepta coma y punto', () {
      expect(textoACentavos('18,25'), 1825);
      expect(textoACentavos('18.25'), 1825);
      expect(textoACentavos('10'), 1000);
      expect(textoACentavos('0,05'), 5);
      expect(textoACentavos(''), isNull);
      expect(textoACentavos('abc'), isNull);
      expect(textoACentavos('18,256'), isNull);
      expect(textoACentavos('-1'), isNull);
    });

    test('centavosATexto siempre muestra dos decimales', () {
      expect(centavosATexto(1025), '10,25');
      expect(centavosATexto(1000), '10,00');
      expect(centavosATexto(5), '0,05');
    });
  });
}
