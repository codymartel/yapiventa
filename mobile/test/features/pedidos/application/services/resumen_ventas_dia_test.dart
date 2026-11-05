import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/resumen_ventas_dia_calculo.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';

import '../../helpers/pedidos_de_prueba.dart';

EntregadoReciente _e(String id) => EntregadoReciente(pedidoId: id);

void main() {
  group('ResumenVentasDia', () {
    test('ticket = ventas ÷ entregados, hacia abajo, una sola vez', () {
      const r = ResumenVentasDia(
        dia: '2026-11-05',
        ventasCentavos: 21460,
        entregados: 9,
      );

      expect(r.ticketCentavos, 2384);
    });

    test('sin entregados no se divide: el ticket es null', () {
      expect(const ResumenVentasDia.vacio('2026-11-05').ticketCentavos, isNull);
    });

    test('minutos promedio para confirmar', () {
      const r = ResumenVentasDia(
        dia: 'd',
        confirmados: 4,
        sumaMinutosConfirmar: 26,
      );

      expect(r.minutosPromedioConfirmar, 6);
      expect(
        const ResumenVentasDia.vacio('d').minutosPromedioConfirmar,
        isNull,
      );
    });
  });

  group('ResumenVentasDiaCalculo', () {
    final ahora = DateTime.utc(2026, 11, 5, 20);

    test('minutos para confirmar: de la llegada a ahora, nunca negativos', () {
      expect(
        ResumenVentasDiaCalculo.minutosParaConfirmar(
          ahora.subtract(const Duration(minutes: 7, seconds: 40)),
          ahora,
        ),
        7,
      );
      expect(
        ResumenVentasDiaCalculo.minutosParaConfirmar(
          ahora.add(const Duration(minutes: 3)),
          ahora,
        ),
        0,
      );
      expect(ResumenVentasDiaCalculo.minutosParaConfirmar(null, ahora), isNull);
    });

    test('el entregado guarda cliente, productos, total y si se cobró', () {
      final pedido = Pedido(
        id: 'p1',
        clave: '7GHMHF',
        estadoPago: EstadoPago.pagado,
        metodoPago: ' Yape ',
        totalCentavos: 1840,
        cliente: const ClientePedido(nombre: ' Rosa Quispe '),
        lineas: [lineaQueso(350), lineaSimple(cantidad: 2)],
      );

      final e = ResumenVentasDiaCalculo.entregadoDe(pedido, ahora);

      expect(e.pedidoId, 'p1');
      expect(e.cliente, 'Rosa Quispe');
      expect(e.productos, '350 Queso andino, 2× Gaseosa Inca');
      expect(e.totalCentavos, 1840);
      expect(e.metodoPago, 'Yape');
      expect(e.cobrado, isTrue);
      expect(e.hora, ahora);
    });

    test('el nuevo va primero y se guardan solo 5', () {
      var lista = <EntregadoReciente>[];
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) {
        lista = ResumenVentasDiaCalculo.conNuevoEntregado(lista, _e(id));
      }

      expect(lista.map((e) => e.pedidoId), ['f', 'e', 'd', 'c', 'b']);
    });

    test('el mismo pedido no se repite', () {
      var lista = [_e('a'), _e('b')];

      lista = ResumenVentasDiaCalculo.conNuevoEntregado(lista, _e('b'));

      expect(lista.map((e) => e.pedidoId), ['b', 'a']);
    });
  });

  group('ResumenVentasDiaMapper', () {
    test('sin documento es un día vacío', () {
      final r = ResumenVentasDiaMapper.desdeFirestore('2026-11-05', null);

      expect(r.dia, '2026-11-05');
      expect(r.ventasCentavos, 0);
      expect(r.ultimosEntregados, isEmpty);
    });

    test('lee los totales y los últimos entregados', () {
      final hora = DateTime.utc(2026, 11, 5, 15, 40);
      final r = ResumenVentasDiaMapper.desdeFirestore('2026-11-05', {
        'ventasCentavos': 21460,
        'entregados': 9,
        'confirmados': 10,
        'sumaMinutosConfirmar': 60,
        'ultimosEntregados': [
          {
            'pedidoId': 'p1',
            'clave': 'ABC',
            'cliente': 'Carla',
            'productos': '2× Combo',
            'totalCentavos': 2100,
            'metodoPago': 'Yape',
            'cobrado': true,
            'hora': Timestamp.fromDate(hora),
          },
        ],
      });

      expect(r.ticketCentavos, 2384);
      expect(r.minutosPromedioConfirmar, 6);
      expect(r.ultimosEntregados.single.cliente, 'Carla');
      expect(r.ultimosEntregados.single.cobrado, isTrue);
      expect(r.ultimosEntregados.single.hora!.toUtc(), hora);
    });

    test('un documento raro no rompe: lo ilegible cuenta como 0', () {
      final r = ResumenVentasDiaMapper.desdeFirestore('d', {
        'ventasCentavos': 'mucho',
        'entregados': -3,
        'ultimosEntregados': 'no es lista',
      });

      expect(r.ventasCentavos, 0);
      expect(r.entregados, 0);
      expect(r.ultimosEntregados, isEmpty);
    });

    test('ida y vuelta de los entregados', () {
      final lista = [
        EntregadoReciente(
          pedidoId: 'p1',
          cliente: 'Carla',
          totalCentavos: 2100,
          cobrado: true,
          hora: DateTime.utc(2026, 11, 5, 15),
        ),
      ];

      final mapas = ResumenVentasDiaMapper.entregadosAMapas(lista);
      final vuelta = ResumenVentasDiaMapper.desdeFirestore('d', {
        'ultimosEntregados': mapas,
      }).ultimosEntregados;

      expect(vuelta.single.pedidoId, 'p1');
      expect(vuelta.single.totalCentavos, 2100);
      expect(vuelta.single.hora!.toUtc(), DateTime.utc(2026, 11, 5, 15));
    });
  });
}
