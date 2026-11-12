import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/data/pedido_mapper.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido_por.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';

import '../helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';
final _ahora = DateTime.utc(2026, 11, 5, 19, 32);

/// Paso R: `pedidoPor` se guarda en la venta en tienda, nunca en delivery, y
/// se lee de forma defensiva.
void main() {
  late FakeFirebaseFirestore db;
  late VentasMostradorRepository repo;

  Future<Map<String, dynamic>> leerPedido(String id) async {
    final doc = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('pedidos')
        .doc(id)
        .get();
    return doc.data()!;
  }

  /// 2 gaseosas a S/ 4,50 = S/ 9,00 en efectivo.
  SolicitudVentaMostrador venta({
    String id = 'venta0001',
    TipoEntrega entrega = TipoEntrega.recojo,
    PedidoPor? por,
  }) {
    final v = CalculoVentaMostrador.calcular(
      lineas: [lineaSimple(cantidad: 2, precioCentavos: 450)],
      deliveryCentavos: 0,
      descuento: DescuentoPago.ninguno,
    );
    final delivery = entrega == TipoEntrega.delivery;
    return SolicitudVentaMostrador(
      idVenta: id,
      lineas: v.lineas,
      tipoEntrega: entrega,
      enLocal: !delivery,
      pedidoPor: por,
      cliente: delivery
          ? const ClientePedido(nombre: 'Rosa', direccion: 'Av. Lima 123')
          : const ClientePedido(),
      zona: delivery ? 'Miraflores' : '',
      subtotalCentavos: v.subtotalCentavos,
      totalCentavos: v.totalCentavos,
      metodoPago: 'efectivo',
    );
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = VentasMostradorRepository(db: db, reloj: () => _ahora);
    final producto = productoSimple(stock: 24, precioCentavos: 450);
    await db
        .collection('negocios')
        .doc(_negocio)
        .collection('productos')
        .doc(producto.id)
        .set(
          ProductoFirestoreMapper.paraFirestore(producto)
            ..['negocioId'] = _negocio,
        );
  });

  group('registrar', () {
    test('la venta en tienda pedida por WhatsApp lo guarda', () async {
      final r = await repo.registrar(_negocio, venta(por: PedidoPor.whatsapp));

      expect(r.registrada, isTrue);
      final datos = await leerPedido('venta0001');
      expect(datos['pedidoPor'], 'whatsapp');
      expect(datos['enLocal'], isTrue);
      expect(datos['estado'], 'entregado');
      expect(datos['estadoPago'], 'pagado', reason: 'se cobra al llegar');
      final pedido = PedidoMapper.desdeFirestore('venta0001', datos);
      expect(pedido.pedidoPor, PedidoPor.whatsapp);
    });

    test('sin pedido previo («No») no escribe el campo', () async {
      await repo.registrar(_negocio, venta());

      expect((await leerPedido('venta0001')).containsKey('pedidoPor'), isFalse);
    });

    test(
      'un delivery nunca lo guarda, aunque llegue en la solicitud',
      () async {
        await repo.registrar(
          _negocio,
          venta(entrega: TipoEntrega.delivery, por: PedidoPor.facebook),
        );

        final datos = await leerPedido('venta0001');
        expect(datos['tipoEntrega'], 'delivery');
        expect(datos.containsKey('pedidoPor'), isFalse);
      },
    );
  });

  group('PedidoMapper', () {
    test('lee pedidoPor; un valor desconocido se lee como «No»', () {
      expect(
        PedidoMapper.desdeFirestore('a', {'pedidoPor': 'llamada'}).pedidoPor,
        PedidoPor.llamada,
      );
      expect(
        PedidoMapper.desdeFirestore('b', {'pedidoPor': 'tiktok'}).pedidoPor,
        isNull,
      );
      expect(
        PedidoMapper.desdeFirestore('c', {'pedidoPor': 3}).pedidoPor,
        isNull,
      );
      expect(PedidoMapper.desdeFirestore('d', {}).pedidoPor, isNull);
    });

    test('copyWith conserva pedidoPor', () {
      const p = Pedido(id: 'x', pedidoPor: PedidoPor.otro);
      expect(
        p.copyWith(estadoPago: EstadoPago.pagado).pedidoPor,
        PedidoPor.otro,
      );
    });
  });
}
