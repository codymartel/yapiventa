import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/carrito_caja.dart';
import 'package:mobile/features/caja/application/services/constructor_linea_caja.dart';
import 'package:mobile/features/caja/application/services/disponibilidad_caja.dart';
import 'package:mobile/features/caja/application/services/mensajes_cobro_caja.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/services/validacion_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

LineaPedido _linea(
  Producto p, {
  int cantidad = 1,
  String m = '',
  String f = '',
  List<String> extras = const [],
}) => ConstructorLineaCaja.construir(
  p,
  cantidad: cantidad,
  modeloId: m,
  filaId: f,
  extrasIds: extras,
).linea!;

void main() {
  group('ConstructorLineaCaja', () {
    test('producto que se cuenta: precio de una unidad', () {
      final l = _linea(productoSimple(precioCentavos: 450), cantidad: 2);

      expect([l.productoId, l.cantidad, l.precioCentavos], ['gaseosa', 2, 450]);
      expect(l.porMedida, isFalse);
      expect(l.esCombo, isFalse);
    });

    test('por peso: la cantidad va en gramos y el precio cubre 1 000 g', () {
      final l = _linea(quesoPorMedida(), cantidad: 350);

      expect(l.porMedida, isTrue);
      expect(
        [l.cantidad, l.precioCentavos, l.cantidadReferencia],
        [350, 2400, 1000],
      );
      expect(CalculoVentaMostrador.calcular(lineas: [l]).subtotalCentavos, 840);
    });

    test('con modelos usa el precio de la fila y arma la etiqueta', () {
      final l = _linea(poloConModelos(), m: 'luna', f: 'l');

      expect(l.precioCentavos, 5500);
      expect(l.etiqueta, 'Luna · L');
    });

    test('con modelos, sin elegir fila o con una que no existe: mensaje', () {
      expect(
        ConstructorLineaCaja.construir(poloConModelos(), cantidad: 1).error,
        isNotNull,
      );
      expect(
        ConstructorLineaCaja.construir(
          poloConModelos(),
          cantidad: 1,
          modeloId: 'luna',
          filaId: 'xl',
        ).ok,
        isFalse,
      );
    });

    test('combo: línea marcada como combo, sin modelos ni extras', () {
      final l = _linea(comboGaseosaYPapas(), cantidad: 2);

      expect(l.esCombo, isTrue);
      expect(l.precioCentavos, 1500);
    });

    test('los extras suman al precio de cada unidad', () {
      final cafe = Producto(
        id: 'cafe',
        negocioId: 'n1',
        nombre: 'Café',
        stock: 5,
        precioCentavos: 350,
        extras: const [
          ExtraProducto(id: 'e1', nombre: 'Leche', precioCentavos: 100),
        ],
      );

      final l = _linea(cafe, cantidad: 2, extras: ['e1']);

      expect(l.extras.single.nombre, 'Leche');
      expect(CalculoVentaMostrador.calcular(lineas: [l]).subtotalCentavos, 900);
    });

    test(
      'un extra que no existe o extras en un producto por peso se rechazan',
      () {
        final cafe = productoSimple();
        expect(
          ConstructorLineaCaja.construir(
            cafe,
            cantidad: 1,
            extrasIds: ['x'],
          ).error,
          isNotNull,
        );
        expect(
          ConstructorLineaCaja.construir(
            quesoPorMedida(),
            cantidad: 100,
            extrasIds: ['x'],
          ).error,
          isNotNull,
        );
      },
    );

    test('cantidad cero o negativa, o producto no disponible: mensaje', () {
      expect(
        ConstructorLineaCaja.construir(productoSimple(), cantidad: 0).ok,
        isFalse,
      );
      expect(
        ConstructorLineaCaja.construir(productoSimple(), cantidad: -1).ok,
        isFalse,
      );
      expect(
        ConstructorLineaCaja.construir(
          productoSimple().copyWith(disponible: false),
          cantidad: 1,
        ).error,
        contains('disponible'),
      );
    });
  });

  group('CarritoCaja', () {
    test('la misma línea suma su cantidad, no se repite', () {
      final a = _linea(productoSimple());
      var c = const CarritoCaja().agregar(a).carrito;
      c = c.agregar(_linea(productoSimple(), cantidad: 2)).carrito;

      expect(c.lineas, hasLength(1));
      expect(c.lineas.single.cantidad, 3);
    });

    test('distinto modelo o fila = otra línea', () {
      var c = const CarritoCaja();
      c = c.agregar(_linea(poloConModelos(), m: 'luna', f: 'm')).carrito;
      c = c.agregar(_linea(poloConModelos(), m: 'luna', f: 'l')).carrito;

      expect(c.lineas, hasLength(2));
    });

    test('el orden de los extras no crea otra línea', () {
      final p = Producto(
        id: 'p',
        negocioId: 'n1',
        nombre: 'P',
        stock: 9,
        precioCentavos: 100,
        extras: const [
          ExtraProducto(id: 'a', nombre: 'A', precioCentavos: 10),
          ExtraProducto(id: 'b', nombre: 'B', precioCentavos: 20),
        ],
      );
      var c = const CarritoCaja()
          .agregar(_linea(p, extras: ['a', 'b']))
          .carrito;
      c = c.agregar(_linea(p, extras: ['b', 'a'])).carrito;

      expect(c.lineas, hasLength(1));
      expect(c.lineas.single.cantidad, 2);
    });

    test('cambiar la cantidad, con 0 se quita, y quitar', () {
      final linea = _linea(productoSimple());
      final clave = CarritoCaja.claveDe(linea);
      var c = const CarritoCaja().agregar(linea).carrito;

      c = c.conCantidad(clave, 5);
      expect(c.cantidadDe(clave), 5);
      expect(c.conCantidad(clave, 0).vacio, isTrue);
      expect(c.quitar(clave).vacio, isTrue);
    });

    test(
      'hasta 30 productos distintos; el 31 no entra, pero sumar a uno sí',
      () {
        var c = const CarritoCaja();
        for (var i = 0; i < CarritoCaja.maximoLineas; i++) {
          c = c
              .agregar(_linea(productoSimple(id: 'p$i', nombre: 'P$i')))
              .carrito;
        }

        final r = c.agregar(_linea(productoSimple(id: 'extra', nombre: 'X')));
        expect(r.ok, isFalse);
        expect(r.carrito.lineas, hasLength(30));
        expect(
          c.agregar(_linea(productoSimple(id: 'p0', nombre: 'P0'))).ok,
          isTrue,
        );
      },
    );
  });

  group('MensajesCobroCaja', () {
    test('venta registrada con el total en soles', () {
      expect(MensajesCobroCaja.registrada(1740), 'Venta registrada · S/ 17,40');
    });

    test('falta de stock dice qué falta y que no se cobró nada', () {
      final m = MensajesCobroCaja.bloqueo(
        const ResultadoVentaMostrador(
          faltas: [FaltaStock(nombre: 'Gaseosa', pide: 3, hay: 2)],
        ),
      );
      expect(m, contains('Gaseosa (pides 3, hay 2)'));
      expect(m, contains('No se cobró nada'));
    });

    test('precio que cambió dice el total nuevo', () {
      final m = MensajesCobroCaja.bloqueo(
        const ResultadoVentaMostrador(
          precioCambio: true,
          totalActualCentavos: 1850,
          lineasCambiadas: ['Queso'],
        ),
      );
      expect(m, contains('cambió: Queso'));
      expect(m, contains('S/ 18,50'));
    });

    test('un producto borrado se nombra', () {
      final m = MensajesCobroCaja.bloqueo(
        const ResultadoVentaMostrador(sinProducto: ['Arroz']),
      );
      expect(m, contains('Ya no existe: Arroz'));
    });

    test('datos que faltan: usa el mensaje de la validación', () {
      final v = ValidacionVentaMostrador.validar(
        lineas: const [],
        metodoPago: '',
        tipoEntrega: TipoEntrega.recojo,
      );
      expect(
        MensajesCobroCaja.noSeCobro(ResultadoRegistroVenta(invalida: v)),
        'Falta: productos y forma de pago',
      );
    });

    test('registrada o ya registrada: no hay motivo de bloqueo', () {
      expect(
        MensajesCobroCaja.noSeCobro(
          const ResultadoRegistroVenta(
            resultado: ResultadoVentaMostrador(registrada: true),
          ),
        ),
        isNull,
      );
      expect(
        MensajesCobroCaja.noSeCobro(
          const ResultadoRegistroVenta(
            resultado: ResultadoVentaMostrador(yaRegistrada: true),
          ),
        ),
        isNull,
      );
    });
  });

  group('DisponibilidadCaja', () {
    test('se cuenta: con stock, sin stock y stock bajo (3 o menos)', () {
      expect(DisponibilidadCaja.tieneStock(productoSimple(stock: 5)), isTrue);
      expect(DisponibilidadCaja.tieneStock(productoSimple(stock: 0)), isFalse);
      expect(DisponibilidadCaja.stockBajo(productoSimple(stock: 3)), isTrue);
      expect(DisponibilidadCaja.stockBajo(productoSimple(stock: 4)), isFalse);
      expect(DisponibilidadCaja.stockBajo(productoSimple(stock: 0)), isFalse);
    });

    test('por medida mira el stock en unidad base y no tiene «stock bajo»', () {
      expect(
        DisponibilidadCaja.tieneStock(quesoPorMedida(stockBase: 0)),
        isFalse,
      );
      expect(
        DisponibilidadCaja.tieneStock(quesoPorMedida(stockBase: 200)),
        isTrue,
      );
      expect(
        DisponibilidadCaja.stockBajo(quesoPorMedida(stockBase: 200)),
        isFalse,
      );
    });

    test('ilimitado y combo siempre se muestran', () {
      expect(
        DisponibilidadCaja.tieneStock(productoSimple(stock: 0, infinito: true)),
        isTrue,
      );
      expect(DisponibilidadCaja.tieneStock(comboGaseosaYPapas()), isTrue);
    });
  });

  test('EntregaCaja: el local se guarda como recojo pero marca enLocal', () {
    expect(EntregaCaja.local.tipo, TipoEntrega.recojo);
    expect(EntregaCaja.local.enLocal, isTrue);
    expect(EntregaCaja.recojo.enLocal, isFalse);
    expect(EntregaCaja.delivery.tipo, TipoEntrega.delivery);
  });
}
