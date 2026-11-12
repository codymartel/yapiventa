import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/domain/models/dia_caja.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/data/pedidos_repository.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';
const _dia5 = '2026-11-05';
const _dia6 = '2026-11-06';

// 19:32 UTC = 14:32 en Lima.
final _el5 = DateTime.utc(2026, 11, 5, 19, 32);
final _el6 = DateTime.utc(2026, 11, 6, 19, 32);

/// La caja y las ventas de Caja con cobros: la plata entra el día en que se
/// cobra, y anular resta lo que se sumó (de cada día).
void main() {
  late FakeFirebaseFirestore db;
  var ahora = _el5;
  late VentasMostradorRepository caja;
  late PedidosRepository pedidos;

  Future<void> guardar(Producto p) {
    return db
        .collection('negocios')
        .doc(_negocio)
        .collection('productos')
        .doc(p.id)
        .set(
          ProductoFirestoreMapper.paraFirestore(p)..['negocioId'] = _negocio,
        );
  }

  Future<DiaCaja> dia(String dia) async {
    final doc = await db
        .collection('negocios')
        .doc(_negocio)
        .collection('resumenes')
        .doc(dia)
        .get();
    return DiaCaja(
      ventas: ResumenVentasDiaMapper.desdeFirestore(dia, doc.data()),
    );
  }

  /// 2 gaseosas a S/ 4,50 = S/ 9,00 en efectivo.
  SolicitudVentaMostrador venta({
    TipoEntrega entrega = TipoEntrega.recojo,
    bool cobrarAlEntregar = false,
  }) {
    final v = CalculoVentaMostrador.calcular(
      lineas: [lineaSimple(cantidad: 2, precioCentavos: 450)],
      deliveryCentavos: 0,
      descuento: DescuentoPago.ninguno,
    );
    final delivery = entrega == TipoEntrega.delivery;
    return SolicitudVentaMostrador(
      idVenta: 'venta0001',
      lineas: v.lineas,
      tipoEntrega: entrega,
      enLocal: !delivery,
      cliente: delivery
          ? const ClientePedido(nombre: 'Rosa', direccion: 'Av. Lima 123')
          : const ClientePedido(),
      zona: delivery ? 'Miraflores' : '',
      deliveryCentavos: v.deliveryCentavos,
      descuentoCentavos: v.descuentoCentavos,
      subtotalCentavos: v.subtotalCentavos,
      totalCentavos: v.totalCentavos,
      metodoPago: 'efectivo',
      cobrarAlEntregar: cobrarAlEntregar,
    );
  }

  /// Delivery de Caja con «cobrar al entregar», llevado hasta la puerta.
  Future<void> deliveryEnCamino() async {
    await caja.registrar(
      _negocio,
      venta(entrega: TipoEntrega.delivery, cobrarAlEntregar: true),
    );
    await pedidos.avanzar(_negocio, 'venta0001', EstadoPedido.enCamino);
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    ahora = _el5;
    caja = VentasMostradorRepository(db: db, reloj: () => ahora);
    pedidos = PedidosRepository(db: db, reloj: () => ahora);
    await guardar(productoSimple(stock: 24, precioCentavos: 450));
  });

  test('venta en el local: entra a la caja y anularla la saca', () async {
    await caja.registrar(_negocio, venta());
    expect((await dia(_dia5)).efectivoCentavos, 900);

    await caja.anular(_negocio, 'venta0001');

    final d = await dia(_dia5);
    expect(d.efectivoCentavos, 0);
    expect(d.ventasCentavos, 0);
  });

  test(
    'delivery entregado sin cobrar y anulado: sale de «por cobrar»',
    () async {
      await deliveryEnCamino();
      await pedidos.avanzar(_negocio, 'venta0001', EstadoPedido.entregado);
      expect((await dia(_dia5)).porCobrarCentavos, 900);
      expect((await dia(_dia5)).efectivoCentavos, 0);

      await caja.anular(_negocio, 'venta0001');

      final d = await dia(_dia5);
      expect(d.porCobrarCentavos, 0);
      expect(d.ventas.contadores.porCobrar, 0);
      expect(d.ventasCentavos, 0);
      expect(d.efectivoCentavos, 0);
    },
  );

  test('entregado el 5, cobrado el 6 y anulado: resta de cada día', () async {
    await deliveryEnCamino();
    await pedidos.avanzar(_negocio, 'venta0001', EstadoPedido.entregado);
    ahora = _el6;
    await pedidos.marcarPago(_negocio, 'venta0001', EstadoPago.pagado);
    expect((await dia(_dia6)).efectivoCentavos, 900);

    await caja.anular(_negocio, 'venta0001');

    expect((await dia(_dia5)).ventasCentavos, 0);
    expect((await dia(_dia5)).porCobrarCentavos, 0);
    expect((await dia(_dia6)).efectivoCentavos, 0);
  });

  test('delivery cobrado en el mostrador el 5 y entregado el 6: anular '
      'resta la plata del 5 y la venta del 6', () async {
    await caja.registrar(_negocio, venta(entrega: TipoEntrega.delivery));
    await pedidos.avanzar(_negocio, 'venta0001', EstadoPedido.enCamino);
    ahora = _el6;
    await pedidos.avanzar(_negocio, 'venta0001', EstadoPedido.entregado);
    expect((await dia(_dia5)).efectivoCentavos, 900);
    expect((await dia(_dia6)).ventasCentavos, 900);
    expect((await dia(_dia6)).efectivoCentavos, 0);

    await caja.anular(_negocio, 'venta0001');

    expect((await dia(_dia5)).efectivoCentavos, 0);
    expect((await dia(_dia6)).ventasCentavos, 0);
  });

  test('delivery cobrado en el mostrador y cancelado antes de salir: '
      'la plata sale de la caja', () async {
    await caja.registrar(_negocio, venta(entrega: TipoEntrega.delivery));
    expect((await dia(_dia5)).efectivoCentavos, 900);

    await pedidos.cancelar(_negocio, 'venta0001');

    expect((await dia(_dia5)).efectivoCentavos, 0);
  });
}
