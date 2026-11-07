import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/calculo_hoja_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

Producto _polo() => Producto(
  id: 'polo',
  negocioId: 'n1',
  nombre: 'Polo básico',
  stock: 8,
  precioCentavos: 3500,
  tituloModelos: 'Color',
  tituloFilas: 'Talla',
  modelos: const [
    ModeloProducto(
      id: 'azul',
      nombre: 'Azul',
      filas: [
        FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 3),
        FilaVenta(id: 'm', etiqueta: 'M', precioCentavos: 3500, stock: 5),
        FilaVenta(id: 'xl', etiqueta: 'XL', precioCentavos: 3800, stock: 0),
      ],
    ),
    ModeloProducto(
      id: 'rojo',
      nombre: 'Rojo',
      filas: [
        FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 2),
      ],
    ),
  ],
  extras: const [
    ExtraProducto(id: 'bord', nombre: 'Bordado', precioCentavos: 800),
  ],
);

void main() {
  group('producto que se cuenta', () {
    test('el subtotal es precio × cantidad', () {
      final r = CalculoHojaProducto.calcular(
        productoSimple(precioCentavos: 450, stock: 22),
        const SeleccionProductoCaja(cantidad: 2),
      );

      expect(r.puedeAgregar, isTrue);
      expect(r.subtotalCentavos, 900);
      expect(r.stockDisponible, 22);
      expect(r.noAlcanza, isFalse);
    });

    test('pedir más de lo que hay: no alcanza y no se puede agregar', () {
      final r = CalculoHojaProducto.calcular(
        productoSimple(stock: 2),
        const SeleccionProductoCaja(cantidad: 3),
      );

      expect(r.noAlcanza, isTrue);
      expect(r.puedeAgregar, isFalse);
    });

    test('sin stock: 0 disponibles', () {
      final r = CalculoHojaProducto.calcular(
        productoSimple(stock: 0),
        const SeleccionProductoCaja(),
      );

      expect(r.stockDisponible, 0);
      expect(r.noAlcanza, isTrue);
    });

    test('ilimitado: no se sabe el stock y el stepper sube hasta el tope', () {
      final p = productoSimple(stock: 0, infinito: true);
      final r = CalculoHojaProducto.calcular(p, const SeleccionProductoCaja());

      expect(r.stockDisponible, isNull);
      expect(r.puedeAgregar, isTrue);
      expect(
        CalculoHojaProducto.maximoDe(p, const SeleccionProductoCaja()),
        CalculoHojaProducto.maximoContable,
      );
    });

    test('un combo: su precio propio y su stock se comprueba al cobrar', () {
      final r = CalculoHojaProducto.calcular(
        comboGaseosaYPapas(),
        const SeleccionProductoCaja(cantidad: 2),
      );

      expect(r.subtotalCentavos, 3000);
      expect(r.stockDisponible, isNull);
      expect(r.puedeAgregar, isTrue);
    });
  });

  group('por medida', () {
    test('350 g de queso a S/ 24,00 el kg = 840 (hacia abajo, una vez)', () {
      final r = CalculoHojaProducto.calcular(
        quesoPorMedida(stockBase: 3200),
        const SeleccionProductoCaja(cantidad: 350),
      );

      expect(r.subtotalCentavos, 840);
      expect(r.resumen, '350 g');
      expect(r.stockDisponible, 3200);
    });

    test('333 g redondea hacia abajo: 799', () {
      final r = CalculoHojaProducto.calcular(
        quesoPorMedida(stockBase: 3200),
        const SeleccionProductoCaja(cantidad: 333),
      );

      expect(r.subtotalCentavos, 799);
    });

    test('un cuarto de kilo se lee «¼ kg»', () {
      final r = CalculoHojaProducto.calcular(
        quesoPorMedida(stockBase: 3200),
        const SeleccionProductoCaja(cantidad: 250),
      );

      expect(r.resumen, '¼ kg');
      expect(r.subtotalCentavos, 600);
    });

    test('sin elegir cantidad no se puede agregar', () {
      final r = CalculoHojaProducto.calcular(
        quesoPorMedida(),
        const SeleccionProductoCaja(cantidad: 0),
      );

      expect(r.puedeAgregar, isFalse);
      expect(r.falta, isNotNull);
    });

    test('más gramos de los que hay: no alcanza', () {
      final r = CalculoHojaProducto.calcular(
        quesoPorMedida(stockBase: 800),
        const SeleccionProductoCaja(cantidad: 1000),
      );

      expect(r.noAlcanza, isTrue);
      expect(r.puedeAgregar, isFalse);
    });

    test('las cantidades rápidas de peso: 1 kg, ½ kg, ¼ kg y 100 g', () {
      final c = CalculoHojaProducto.cantidadesRapidas(quesoPorMedida());

      expect(c.map((e) => e.base), [1000, 500, 250, 100]);
      expect(c.map((e) => e.etiqueta), ['1 kg', '½ kg', '¼ kg', '100 g']);
    });

    test('un producto que se cuenta no tiene cantidades rápidas', () {
      expect(CalculoHojaProducto.cantidadesRapidas(productoSimple()), isEmpty);
    });
  });

  group('variables', () {
    test('sin elegir modelo y fila falta elegir', () {
      final r = CalculoHojaProducto.calcular(
        _polo(),
        const SeleccionProductoCaja(),
      );

      expect(r.puedeAgregar, isFalse);
      expect(r.falta, contains('Elige'));
    });

    test('el stock es el de la fila elegida', () {
      final r = CalculoHojaProducto.calcular(
        _polo(),
        const SeleccionProductoCaja(modeloId: 'azul', filaId: 's'),
      );

      expect(r.stockDisponible, 3);
      expect(r.resumen, 'Azul · S');
    });

    test('un extra suma a cada unidad y entra en el resumen', () {
      final r = CalculoHojaProducto.calcular(
        _polo(),
        const SeleccionProductoCaja(
          modeloId: 'azul',
          filaId: 'm',
          cantidad: 2,
          extrasIds: {'bord'},
        ),
      );

      expect(r.subtotalCentavos, (3500 + 800) * 2);
      expect(r.resumen, 'Azul · M · bordado');
    });

    test('con un solo modelo el resumen no repite su nombre', () {
      final unico = Producto(
        id: 'pollo',
        negocioId: 'n1',
        nombre: 'Pollo a la brasa',
        esStockInfinito: true,
        precioCentavos: 1800,
        modelos: const [
          ModeloProducto(
            id: 'p',
            nombre: 'Pollo',
            filas: [
              FilaVenta(id: 'm', etiqueta: 'Medio', precioCentavos: 3400),
            ],
          ),
        ],
      );

      final r = CalculoHojaProducto.calcular(
        unico,
        const SeleccionProductoCaja(modeloId: 'p', filaId: 'm'),
      );

      expect(r.resumen, 'Medio');
      expect(r.linea!.etiqueta, 'Pollo · Medio', reason: 'la línea no cambia');
    });

    test('la fila agotada no alcanza para ninguna unidad', () {
      final r = CalculoHojaProducto.calcular(
        _polo(),
        const SeleccionProductoCaja(modeloId: 'azul', filaId: 'xl'),
      );

      expect(r.stockDisponible, 0);
      expect(r.puedeAgregar, isFalse);
    });

    test('el precio es el de la fila (XL cuesta más)', () {
      final r = CalculoHojaProducto.calcular(
        _polo(),
        const SeleccionProductoCaja(modeloId: 'azul', filaId: 'xl'),
      );

      expect(r.subtotalCentavos, 3800);
    });
  });

  group('SeleccionProductoCaja', () {
    test('cambiar de modelo borra la fila', () {
      final s = const SeleccionProductoCaja(
        modeloId: 'azul',
        filaId: 'm',
        cantidad: 3,
      ).conModelo('rojo');

      expect(s.modeloId, 'rojo');
      expect(s.filaId, '');
      expect(s.cantidad, 3, reason: 'la cantidad se conserva');
    });

    test('poner y quitar un extra', () {
      var s = const SeleccionProductoCaja().conExtra('a', true);
      s = s.conExtra('b', true).conExtra('a', false);

      expect(s.extrasIds, {'b'});
    });
  });
}
