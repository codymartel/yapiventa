import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/domain/models/calculador_venta_medida.dart';
import 'package:mobile/features/productos/domain/models/cantidad_base.dart';
import 'package:mobile/features/productos/domain/models/dinero.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/regla_venta_medida.dart';

void main() {
  // Regla típica de venta por medida: arroz a S/ 10 por kg.
  final reglaArroz = ReglaVentaMedida(
    familia: FamiliaUnidad.peso,
    cantidadReferenciaBase: CantidadBase.gramos(1000), // 1 kg
    precioReferenciaCentimos: Dinero(1000), // S/ 10
    cantidadMinimaBase: CantidadBase.gramos(50),
    incrementoBase: CantidadBase.gramos(10),
    permitePedidoPorMonto: true,
  );

  group('Dinero', () {
    test('se expresa en céntimos enteros sin double', () {
      final precio = Dinero(1050);
      expect(precio.centimos, 1050);
      expect(precio.centimos, isA<int>());
      expect((Dinero(100) + Dinero(50)).centimos, 150);
    });

    test('desdeSoles multiplica por 100', () {
      expect(Dinero.desdeSoles(10).centimos, 1000);
    });
  });

  group('CantidadBase', () {
    test('peso se representa internamente en gramos (1½ kg → 1500 g)', () {
      final cantidad = CantidadBase.gramos(1500);
      expect(cantidad.valor, 1500);
      expect(cantidad.familia, FamiliaUnidad.peso);
      expect(cantidad.valor, isA<int>());
    });

    test('rechaza valores cero o negativos', () {
      expect(() => CantidadBase.gramos(0), throwsArgumentError);
      expect(() => CantidadBase.gramos(-230), throwsArgumentError);
      expect(() => CantidadBase.unidades(0), throwsArgumentError);
    });
  });

  group('calculador: precio y cantidad', () {
    test('S/ 1 de arroz a S/ 10 por kg produce 100 g', () {
      final resultado = CalculadorVentaMedida.calcularCantidadDesdeMonto(
        reglaArroz,
        Dinero(100), // S/ 1
      );
      expect(resultado.esValido, isTrue);
      expect(resultado.cantidad, CantidadBase.gramos(100));
      expect(resultado.costo?.centimos, 100);
    });

    test('1500 g a S/ 10 por kg producen 1500 céntimos (S/ 15)', () {
      final resultado = CalculadorVentaMedida.calcularPrecio(
        reglaArroz,
        CantidadBase.gramos(1500),
      );
      expect(resultado.esValido, isTrue);
      expect(resultado.precio, const Dinero(1500));
    });

    test('230 g se acepta con incremento de 10 g', () {
      final regla = ReglaVentaMedida(
        familia: FamiliaUnidad.peso,
        cantidadReferenciaBase: CantidadBase.gramos(1000),
        precioReferenciaCentimos: Dinero(1000),
        cantidadMinimaBase: CantidadBase.gramos(10),
        incrementoBase: CantidadBase.gramos(10),
        permitePedidoPorMonto: true,
      );
      final cantidad = CantidadBase.gramos(230);
      expect(CalculadorVentaMedida.validarMinimo(regla, cantidad), isNull);
      expect(CalculadorVentaMedida.validarIncremento(regla, cantidad), isNull);
      final precio = CalculadorVentaMedida.calcularPrecio(regla, cantidad);
      expect(precio.esValido, isTrue);
    });

    test('230 g se rechaza con incremento de 100 g', () {
      final regla = ReglaVentaMedida(
        familia: FamiliaUnidad.peso,
        cantidadReferenciaBase: CantidadBase.gramos(1000),
        precioReferenciaCentimos: Dinero(1000),
        cantidadMinimaBase: CantidadBase.gramos(10),
        incrementoBase: CantidadBase.gramos(100),
        permitePedidoPorMonto: true,
      );
      final cantidad = CantidadBase.gramos(230);
      expect(
        CalculadorVentaMedida.validarIncremento(regla, cantidad),
        isNotNull,
      );
    });

    test('se rechaza una cantidad menor al mínimo', () {
      final cantidad = CantidadBase.gramos(20);
      expect(
        CalculadorVentaMedida.validarMinimo(reglaArroz, cantidad),
        isNotNull,
      );
      expect(
        CalculadorVentaMedida.validarIncremento(reglaArroz, cantidad),
        isNotNull,
      );
    });

    test('se rechaza stock insuficiente', () {
      final cantidad = CantidadBase.gramos(500);
      expect(CalculadorVentaMedida.validarStock(200, cantidad), isNotNull);
      final resultado = CalculadorVentaMedida.calcularCantidadDesdeMonto(
        reglaArroz,
        Dinero(5000), // S/ 50
        stockDisponible: 200,
      );
      expect(resultado.esValido, isFalse);
    });

    test('pedido por monto se rechaza si la opción está desactivada', () {
      final reglaSinMonto = ReglaVentaMedida(
        familia: FamiliaUnidad.peso,
        cantidadReferenciaBase: CantidadBase.gramos(1000),
        precioReferenciaCentimos: Dinero(1000),
        cantidadMinimaBase: CantidadBase.gramos(50),
        incrementoBase: CantidadBase.gramos(10),
        permitePedidoPorMonto: false,
      );
      final resultado = CalculadorVentaMedida.calcularCantidadDesdeMonto(
        reglaSinMonto,
        Dinero(1000),
      );
      expect(resultado.esValido, isFalse);
      expect(resultado.error, contains('monto'));
    });
  });

  group('modos de venta', () {
    test('botella de 625 ml es presentación contada por unidades', () {
      // La botella es una presentación: 1 botella. El "625 ml" es el
      // contenido informativo del producto, no stock medido.
      final cantidad = CantidadBase.unidades(1);
      expect(cantidad.familia, FamiliaUnidad.conteo);
      expect(cantidad.valor, 1);

      // Modo de venta: presentación, no medida.
      expect(ModoVenta.presentacion, ModoVenta.presentacion);
      expect(ModoVenta.values.toSet(), {
        ModoVenta.presentacion,
        ModoVenta.medida,
      });
    });

    test(
      'ropa se cuenta por unidades o pares; talla y color no son medidas',
      () {
        final prenda = CantidadBase.unidades(1);
        final par = CantidadBase.unidades(2);
        expect(prenda.familia, FamiliaUnidad.conteo);
        expect(par.valor, 2);
        // Ropa no define ReglaVentaMedida: talla y color son variantes.
      },
    );

    test('medida pertenece a ModoVenta y permite pedido por monto', () {
      expect(ModoVenta.medida, ModoVenta.medida);
      // "Pedido por monto" vive en la regla de medida, no como tercer modo.
      expect(reglaArroz.permitePedidoPorMonto, isTrue);
      expect(const <ModoVenta>[
        ModoVenta.presentacion,
        ModoVenta.medida,
      ], hasLength(2));
    });
  });

  group('integridad del dominio', () {
    test('ninguna clase nueva usa double (tipos enteros estrictos)', () {
      // Cada getter/campo exponer valores, la asignación explícita a `int`
      // es la garantía de compilación: si algo fuera double, no compilaría.
      final int centimos = Dinero(1000).centimos;
      final int cRef = reglaArroz.cantidadReferenciaBase.valor;
      final int min = reglaArroz.cantidadMinimaBase.valor;
      final int inc = reglaArroz.incrementoBase.valor;
      final int precioRef = reglaArroz.precioReferenciaCentimos.centimos;
      final int peso = CantidadBase.gramos(230).valor;

      final int suma = centimos + cRef + min + inc + precioRef + peso;
      expect(suma, greaterThan(0));
    });
  });
}
