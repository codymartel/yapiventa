import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/data/pedido_mapper.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';

void main() {
  test('lee un pedido completo de la tienda', () {
    final p = PedidoMapper.desdeFirestore('abc123XYZ', {
      'clave': '7GHMHF',
      'estado': 'confirmado',
      'tipoEntrega': 'recojo',
      'fecha': Timestamp.fromDate(DateTime.utc(2026, 11, 5, 16, 12)),
      'cliente': {
        'nombre': 'Rosa Quispe',
        'telefono': '987654321',
        'direccion': 'Av. Los Olivos 245',
      },
      'zona': 'Zona Norte',
      'deliveryCentavos': 300,
      'subtotalCentavos': 1540,
      'totalCentavos': 1840,
      'metodoPago': 'yape',
      'estadoPago': 'pagado',
      'notas': 'Sin hielo',
      'lineas': [
        {
          'productoId': 'queso',
          'nombre': 'Queso andino',
          'cantidad': 350,
          'precioCentavos': 2400,
          'porMedida': true,
          'cantidadReferencia': 1000,
          'subtotalCentavos': 840,
        },
        {
          'productoId': 'gaseosa',
          'nombre': 'Gaseosa Inca',
          'cantidad': 2,
          'precioCentavos': 350,
          'extras': [
            {'nombre': 'Con hielo', 'precioCentavos': 0},
          ],
        },
      ],
    });

    expect(p.clave, '7GHMHF');
    expect(p.estado, EstadoPedido.confirmado);
    expect(p.tipoEntrega, TipoEntrega.recojo);
    // Firestore entrega la hora en la zona del dispositivo: se compara el momento.
    expect(p.fecha!.toUtc(), DateTime.utc(2026, 11, 5, 16, 12));
    expect(p.cliente.nombre, 'Rosa Quispe');
    expect(p.totalCentavos, 1840);
    expect(p.estadoPago, EstadoPago.pagado);
    expect(p.lineas, hasLength(2));
    expect(p.lineas.first.porMedida, isTrue);
    expect(p.lineas.first.cantidadReferencia, 1000);
    expect(p.lineas.last.extras.single.nombre, 'Con hielo');
  });

  test(
    'un documento casi vacío o raro no rompe: pedido nuevo con clave del id',
    () {
      final p = PedidoMapper.desdeFirestore('abc123xyz', {
        'estado': 'algo-raro',
        'cliente': 'Juan',
        'totalCentavos': 'no-es-numero',
        'lineas': 'tampoco',
        'historial': [
          {'estado': 'confirmado'}, // sin fecha: se omite
          'basura',
        ],
      });

      expect(p.clave, '123XYZ');
      expect(p.estado, EstadoPedido.nuevo);
      expect(p.cliente.nombre, 'Juan');
      expect(p.totalCentavos, 0);
      expect(p.lineas, isEmpty);
      expect(p.historial, isEmpty);
      expect(p.fecha, isNull);
    },
  );

  test('lee los estados de la app anterior', () {
    final p = PedidoMapper.desdeFirestore('x', {
      'estado': 'pendiente_reembolso',
      'estadoPago': 'reembolsado',
    });

    expect(p.estado, EstadoPedido.cancelado);
    expect(p.estadoPago, EstadoPago.pagado);
  });

  test(
    'una referencia de medida en 0 se lee como 1 (nunca divide por cero)',
    () {
      final p = PedidoMapper.desdeFirestore('x', {
        'lineas': [
          {'productoId': 'q', 'cantidad': 1, 'cantidadReferencia': 0},
        ],
      });

      expect(p.lineas.single.cantidadReferencia, 1);
    },
  );

  test('descuentos e historial se escriben y se leen igual', () {
    final fecha = DateTime.utc(2026, 11, 5, 16);
    final p = PedidoMapper.desdeFirestore('x', {
      'stockDescontado': PedidoMapper.descuentosAMapas(const [
        DescuentoStock(productoId: 'queso', cantidad: 350, enBase: true),
        DescuentoStock(
          productoId: 'polo',
          modeloId: 'luna',
          filaId: 'm',
          cantidad: 2,
        ),
      ]),
      'historial': PedidoMapper.historialAMapas([
        CambioEstado(estado: EstadoPedido.confirmado, fecha: fecha),
      ]),
    });

    expect(p.stockDescontado, hasLength(2));
    expect(p.stockDescontado.first.enBase, isTrue);
    expect(p.stockDescontado.last.filaId, 'm');
    expect(p.historial.single.estado, EstadoPedido.confirmado);
    expect(p.historial.single.fecha.toUtc(), fecha);
  });

  group('origen del pedido', () {
    test('un pedido viejo, sin el campo, es de la tienda', () {
      final p = PedidoMapper.desdeFirestore('x', {'estado': 'nuevo'});

      expect(p.origen, OrigenPedido.tienda);
    });

    test('lee una venta de mostrador', () {
      final p = PedidoMapper.desdeFirestore('x', {'origen': 'mostrador'});

      expect(p.origen, OrigenPedido.mostrador);
    });

    test('un valor raro se toma como tienda (lectura defensiva)', () {
      final p = PedidoMapper.desdeFirestore('x', {'origen': 'otra-cosa'});

      expect(p.origen, OrigenPedido.tienda);
    });

    test('copyWith conserva el origen', () {
      final p = PedidoMapper.desdeFirestore('x', {'origen': 'mostrador'});

      expect(
        p.copyWith(estado: EstadoPedido.entregado).origen,
        OrigenPedido.mostrador,
      );
    });
  });
}
