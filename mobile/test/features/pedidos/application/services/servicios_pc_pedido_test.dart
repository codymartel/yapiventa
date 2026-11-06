import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/busqueda_pedidos.dart';
import 'package:mobile/features/pedidos/application/services/indicadores_pedidos.dart';
import 'package:mobile/features/pedidos/application/services/por_preparar_pedidos.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';

final _ahora = DateTime.utc(2026, 11, 5, 20);

Pedido _p(
  String id, {
  EstadoPedido estado = EstadoPedido.nuevo,
  EstadoPago pago = EstadoPago.pendiente,
  Duration hace = const Duration(minutes: 5),
  int total = 1000,
  String nombre = 'Cliente',
  String telefono = '',
  String clave = 'ABC123',
  List<LineaPedido> lineas = const [],
}) {
  return Pedido(
    id: id,
    clave: clave,
    estado: estado,
    estadoPago: pago,
    fecha: _ahora.subtract(hace),
    totalCentavos: total,
    cliente: ClientePedido(nombre: nombre, telefono: telefono),
    lineas: lineas,
  );
}

LineaPedido _l(String id, String nombre, int cantidad, {bool medida = false}) {
  return LineaPedido(
    productoId: id,
    nombre: nombre,
    cantidad: cantidad,
    precioCentavos: 100,
    porMedida: medida,
  );
}

void main() {
  group('IndicadoresPedidos', () {
    test('cuenta nuevos, activos, en camino y el nuevo más viejo', () {
      final i = IndicadoresPedidos.calcular(
        nuevos: [
          _p('a', hace: const Duration(minutes: 4)),
          _p('b', hace: const Duration(minutes: 21)),
        ],
        activos: [
          _p('c', estado: EstadoPedido.confirmado),
          _p('d', estado: EstadoPedido.enCamino),
          _p('e', estado: EstadoPedido.listo),
        ],
        ahora: _ahora,
      );

      expect(i.nuevos, 2);
      expect(i.minutosDelNuevoMasViejo, 21);
      expect(i.activos, 3);
      expect(i.enCamino, 1);
      expect(i.vencidos, 0);
    });

    test('un nuevo con más de 12 h es vencido', () {
      final i = IndicadoresPedidos.calcular(
        nuevos: [
          _p('a', hace: const Duration(hours: 13)),
          _p('b'),
        ],
        activos: const [],
        ahora: _ahora,
      );

      expect(i.vencidos, 1);
    });

    test('por cobrar suma solo lo pendiente, en céntimos enteros', () {
      final i = IndicadoresPedidos.calcular(
        nuevos: [_p('a', total: 1840), _p('b', total: 1250)],
        activos: [
          _p(
            'c',
            estado: EstadoPedido.confirmado,
            pago: EstadoPago.pagado,
            total: 3200,
          ),
          _p('d', estado: EstadoPedido.enCamino, total: 2550),
        ],
        ahora: _ahora,
      );

      expect(i.porCobrarCentavos, 5640);
      expect(i.porCobrarPedidos, 3);
    });

    test('sin pedidos todo es cero y no hay más viejo', () {
      final i = IndicadoresPedidos.calcular(
        nuevos: const [],
        activos: const [],
        ahora: _ahora,
      );

      expect(i.nuevos, 0);
      expect(i.minutosDelNuevoMasViejo, isNull);
      expect(i.porCobrarCentavos, 0);
    });

    test('un reloj atrasado no da minutos negativos', () {
      final i = IndicadoresPedidos.calcular(
        nuevos: [_p('a', hace: const Duration(minutes: -10))],
        activos: const [],
        ahora: _ahora,
      );

      expect(i.minutosDelNuevoMasViejo, 0);
    });
  });

  group('PorPrepararPedidos', () {
    test('suma lo mismo de varios pedidos y ordena por nombre', () {
      final items = PorPrepararPedidos.sumar([
        _p(
          'a',
          lineas: [_l('inca', 'Gaseosa Inca', 2), _l('arroz', 'Arroz', 1)],
        ),
        _p(
          'b',
          estado: EstadoPedido.confirmado,
          lineas: [_l('inca', 'Gaseosa Inca', 3)],
        ),
      ]);

      expect(items.map((e) => e.nombre), ['Arroz', 'Gaseosa Inca']);
      expect(items.last.cantidad, 5);
      expect(items.last.cantidadTexto, '×5');
    });

    test('por medida suma en unidad base entera (350 g + 200 g)', () {
      final items = PorPrepararPedidos.sumar([
        _p('a', lineas: [_l('queso', 'Queso andino', 350, medida: true)]),
        _p('b', lineas: [_l('queso', 'Queso andino', 200, medida: true)]),
      ]);

      expect(items.single.cantidad, 550);
      expect(items.single.cantidadTexto, '550');
    });

    test('los que ya salieron no se preparan', () {
      final items = PorPrepararPedidos.sumar([
        _p('a', estado: EstadoPedido.enCamino, lineas: [_l('x', 'X', 1)]),
        _p('b', estado: EstadoPedido.listo, lineas: [_l('x', 'X', 1)]),
        _p('c', estado: EstadoPedido.entregado, lineas: [_l('x', 'X', 1)]),
      ]);

      expect(items, isEmpty);
    });

    test('un modelo y otro del mismo producto van separados', () {
      const luna = LineaPedido(
        productoId: 'polo',
        modeloId: 'luna',
        filaId: 'm',
        nombre: 'Polo',
        etiqueta: 'Luna · M',
        cantidad: 1,
        precioCentavos: 5000,
      );
      const sol = LineaPedido(
        productoId: 'polo',
        modeloId: 'sol',
        filaId: 'm',
        nombre: 'Polo',
        etiqueta: 'Sol · M',
        cantidad: 2,
        precioCentavos: 5000,
      );

      final items = PorPrepararPedidos.sumar([
        _p('a', lineas: [luna, sol]),
      ]);

      expect(items, hasLength(2));
      expect(items.map((e) => e.nombre), ['Polo (Luna · M)', 'Polo (Sol · M)']);
    });
  });

  group('BusquedaPedidos', () {
    final lista = [
      _p('a', clave: '7GHMHF', nombre: 'Rosa Quispe', telefono: '987 654 321'),
      _p('b', clave: 'K3M9TA', nombre: 'José Peña', telefono: '912 345 678'),
    ];

    test('sin texto devuelve todo', () {
      expect(BusquedaPedidos.filtrar(lista, '  '), lista);
    });

    test('por clave, sin importar mayúsculas', () {
      expect(BusquedaPedidos.filtrar(lista, '7ghm').single.id, 'a');
    });

    test('por nombre, sin importar tildes ni mayúsculas', () {
      expect(BusquedaPedidos.filtrar(lista, 'jose pena').single.id, 'b');
      expect(BusquedaPedidos.filtrar(lista, 'ROSA').single.id, 'a');
    });

    test('por teléfono, comparando solo dígitos', () {
      expect(BusquedaPedidos.filtrar(lista, '987-654').single.id, 'a');
      expect(BusquedaPedidos.filtrar(lista, '345').single.id, 'b');
    });

    test('pocos dígitos no buscan en teléfonos', () {
      expect(BusquedaPedidos.filtrar(lista, '98'), isEmpty);
    });

    test('sin coincidencias queda vacío', () {
      expect(BusquedaPedidos.filtrar(lista, 'zzz'), isEmpty);
    });
  });
}
