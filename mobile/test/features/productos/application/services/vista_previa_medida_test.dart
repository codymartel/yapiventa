import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/application/services/lectura_unidades_producto.dart';
import 'package:mobile/features/productos/application/services/vista_previa_medida.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

void main() {
  group('VistaPreviaMedida', () {
    final regla = VistaPreviaMedida.regla(
      familia: FamiliaUnidad.peso,
      precioCentavos: 450, // S/ 4.50 por kg
      referenciaBase: 1000,
      minimoBase: 100,
      incrementoBase: 50,
      permiteMonto: true,
    )!;

    test('cada cantidad rápida cuesta lo justo, redondeado hacia abajo', () {
      final rapidas = VistaPreviaMedida.cantidadesRapidas(
        regla,
        RegistroUnidades.kg,
        const [250, 500, 750, 1000],
      );

      expect(rapidas.map((r) => r.cantidadBase), [250, 500, 750, 1000]);
      // 250 g × 450 / 1000 = 112,5 → 112 céntimos (a favor del cliente).
      expect(rapidas.map((r) => r.precioCentavos), [112, 225, 337, 450]);
    });

    test('las rápidas que no respetan mínimo e incremento no se ofrecen', () {
      final propia = VistaPreviaMedida.regla(
        familia: FamiliaUnidad.peso,
        precioCentavos: 450,
        referenciaBase: 1000,
        minimoBase: 500,
        incrementoBase: 500,
      )!;

      final rapidas = VistaPreviaMedida.cantidadesRapidas(
        propia,
        RegistroUnidades.kg,
        const [250, 500, 750, 1000],
      );

      expect(rapidas.map((r) => r.cantidadBase), [500, 1000]);
    });

    test('por monto entrega lo que alcanza sin cobrar de más', () {
      final monto = VistaPreviaMedida.porMonto(regla, RegistroUnidades.kg)!;

      // S/ 2.00 → 444 g → al incremento: 400 g → se cobra S/ 1.80.
      expect(monto.esValido, isTrue);
      expect(monto.cantidadBase, 400);
      expect(monto.costoCentavos, 180);
      expect(monto.costoCentavos! <= monto.montoCentavos, isTrue);
    });

    test('por monto que no alcanza el mínimo avisa', () {
      final cara = VistaPreviaMedida.regla(
        familia: FamiliaUnidad.peso,
        precioCentavos: 5000, // S/ 50 por kg
        referenciaBase: 1000,
        minimoBase: 100,
        incrementoBase: 50,
        permiteMonto: true,
      )!;

      final monto = VistaPreviaMedida.porMonto(cara, RegistroUnidades.kg)!;

      expect(monto.esValido, isFalse);
      expect(monto.error, isNotNull);
    });

    test('sin venta por monto no hay ejemplo', () {
      final sinMonto = VistaPreviaMedida.regla(
        familia: FamiliaUnidad.peso,
        precioCentavos: 450,
        referenciaBase: 1000,
        minimoBase: 100,
        incrementoBase: 50,
      )!;

      expect(VistaPreviaMedida.porMonto(sinMonto, RegistroUnidades.kg), isNull);
    });

    test('sin precio o con datos en cero no hay regla', () {
      expect(
        VistaPreviaMedida.regla(
          familia: FamiliaUnidad.peso,
          precioCentavos: 0,
          referenciaBase: 1000,
          minimoBase: 100,
          incrementoBase: 50,
        ),
        isNull,
      );
      expect(
        VistaPreviaMedida.regla(
          familia: FamiliaUnidad.longitud,
          precioCentavos: 1200,
          referenciaBase: 1000,
          minimoBase: 0,
          incrementoBase: 250,
        ),
        isNull,
      );
    });

    test('funciona igual en longitud (tela por metro)', () {
      final tela = VistaPreviaMedida.regla(
        familia: FamiliaUnidad.longitud,
        precioCentavos: 1200, // S/ 12 por m
        referenciaBase: 1000, // 1 m = 1000 mm
        minimoBase: 500,
        incrementoBase: 250,
      )!;

      final rapidas = VistaPreviaMedida.cantidadesRapidas(
        tela,
        RegistroUnidades.m,
        const [500, 1000, 2000],
      );

      expect(rapidas.map((r) => r.precioCentavos), [600, 1200, 2400]);
    });
  });

  group('LecturaUnidadesProducto textos de presentación', () {
    test('plural de presentaciones', () {
      expect(LecturaUnidadesProducto.plural('Unidad'), 'unidades');
      expect(LecturaUnidadesProducto.plural('Botella'), 'botellas');
      expect(LecturaUnidadesProducto.plural('Porción'), 'porciones');
      expect(LecturaUnidadesProducto.plural('Par'), 'pares');
      expect(LecturaUnidadesProducto.plural('Set'), 'sets');
      expect(LecturaUnidadesProducto.plural('Sachet'), 'sachets');
    });

    test('texto del precio por presentación', () {
      expect(
        LecturaUnidadesProducto.textoPorPresentacion(
          nombre: 'Unidad',
          formatoEtiqueta: '1 unidad',
          formatoEsUnaUnidad: true,
        ),
        'por unidad',
      );
      expect(
        LecturaUnidadesProducto.textoPorPresentacion(
          nombre: 'Botella',
          formatoEtiqueta: '500 ml',
          formatoEsUnaUnidad: false,
        ),
        'por botella (500 ml)',
      );
    });
  });
}
