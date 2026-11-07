import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/caja/presentation/providers/venta_caja_provider.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';
final _ahora = DateTime.utc(2026, 11, 5, 19, 32);

const _efectivo = OpcionPagoCaja(id: 'efectivo', etiqueta: 'Efectivo');
const _yape = OpcionPagoCaja(
  id: 'yape',
  etiqueta: 'Yape',
  descuento: DescuentoPago.porcentaje(centesimas: 500),
);
const _centro = ZonaCaja(nombre: 'Centro', costoCentavos: 300);

/// Un repositorio que responde lo que se le programe y cuenta las llamadas.
class _RepoFalso implements RepositorioVentasMostrador {
  ResultadoVentaMostrador respuesta = const ResultadoVentaMostrador(
    registrada: true,
    pedidoId: 'v',
    clave: 'ABC123',
  );
  Object? falla;
  final List<SolicitudVentaMostrador> pedidas = [];

  @override
  Future<ResultadoVentaMostrador> registrar(
    String negocioId,
    SolicitudVentaMostrador solicitud,
  ) async {
    pedidas.add(solicitud);
    if (falla != null) throw falla!;
    return respuesta;
  }

  @override
  Future<ResultadoAnulacion> anular(String negocioId, String pedidoId) async =>
      const ResultadoAnulacion();

  @override
  Future<List<ResumenVentasDia>> obtenerResumenes(
    String negocioId,
    String desde,
    String hasta,
  ) async => const [];
}

void main() {
  late _RepoFalso repo;
  var contador = 0;

  VentaCajaProvider crear({
    List<OpcionPagoCaja> pagos = const [_efectivo, _yape],
    List<ZonaCaja> zonas = const [_centro],
  }) {
    contador = 0;
    return VentaCajaProvider(
      negocioId: _negocio,
      registrar: RegistrarVentaMostrador(repo),
      opcionesPago: pagos,
      zonas: zonas,
      generarId: () => 'id-${++contador}',
    );
  }

  setUp(() => repo = _RepoFalso());

  group('armar la venta', () {
    test('empieza con el primer pago, en el local y con el carrito vacío', () {
      final p = crear();

      expect(p.pago, _efectivo);
      expect(p.entrega.name, 'local');
      expect(p.carrito.vacio, isTrue);
      expect(p.puedeCobrar, isFalse);
      expect(p.idVenta, 'id-1');
    });

    test('agregar productos calcula el total en céntimos', () {
      final p = crear();

      expect(p.agregarProducto(quesoPorMedida(), cantidad: 350), isNull);
      expect(
        p.agregarProducto(productoSimple(precioCentavos: 450), cantidad: 2),
        isNull,
      );

      expect(p.venta.subtotalCentavos, 840 + 900);
      expect(p.venta.totalCentavos, 1740);
      expect(p.puedeCobrar, isTrue);
    });

    test('el descuento sale de la forma de pago: Yape 5 % de 1 740 = 87', () {
      final p = crear();
      p.agregarProducto(quesoPorMedida(), cantidad: 350);
      p.agregarProducto(productoSimple(precioCentavos: 450), cantidad: 2);

      p.elegirPago(_yape);

      expect(p.venta.descuentoCentavos, 87);
      expect(p.venta.totalCentavos, 1653);
    });

    test('delivery suma el costo de la zona; en el local no', () {
      final p = crear();
      p.agregarProducto(productoSimple(precioCentavos: 450), cantidad: 2);
      p.elegirZona(_centro);

      expect(p.venta.totalCentavos, 900, reason: 'en el local no hay delivery');
      p.elegirEntrega(EntregaCaja.delivery);
      expect(p.venta.totalCentavos, 1200);
    });

    test('un producto que no se puede agregar devuelve el motivo', () {
      final p = crear();

      expect(p.agregarProducto(poloConModelos(), cantidad: 1), isNotNull);
      expect(p.carrito.vacio, isTrue);
    });

    test('cambiar a una entrega sin delivery apaga «cobrar al entregar»', () {
      final p = crear();
      p.elegirEntrega(EntregaCaja.delivery);
      p.cobrarAlEntregarActivo(true);
      expect(p.cobrarAlEntregar, isTrue);

      p.elegirEntrega(EntregaCaja.recojo);

      expect(p.cobrarAlEntregar, isFalse);
      p.cobrarAlEntregarActivo(true);
      expect(p.cobrarAlEntregar, isFalse, reason: 'solo aplica al delivery');
    });
  });

  group('cobrar', () {
    VentaCajaProvider conVenta() {
      final p = crear();
      p.agregarProducto(productoSimple(precioCentavos: 450), cantidad: 2);
      return p;
    }

    test(
      'registra, devuelve el total y deja todo listo para otra venta',
      () async {
        final p = conVenta();

        final r = await p.cobrar();

        expect(r.tipo, TipoCobroCaja.exito);
        expect(r.mensaje, 'Venta registrada · S/ 9,00');
        expect(r.totalCentavos, 900);
        expect(p.carrito.vacio, isTrue);
        expect(p.idVenta, 'id-2', reason: 'la venta nueva estrena id');
        final s = repo.pedidas.single;
        expect(s.idVenta, 'id-1');
        expect(s.totalCentavos, 900);
        expect(s.metodoPago, 'efectivo');
        expect(s.enLocal, isTrue);
      },
    );

    test('un doble toque cobra una sola vez', () async {
      final p = conVenta();

      final a = p.cobrar();
      final b = await p.cobrar();
      await a;

      expect(b.tipo, TipoCobroCaja.ignorado);
      expect(repo.pedidas, hasLength(1));
    });

    test(
      'faltan datos (delivery sin cliente): no se llama al repositorio',
      () async {
        final p = conVenta();
        p.elegirEntrega(EntregaCaja.delivery);

        final r = await p.cobrar();

        expect(r.tipo, TipoCobroCaja.faltanDatos);
        expect(r.mensaje, startsWith('Falta:'));
        expect(repo.pedidas, isEmpty);
        expect(p.carrito.vacio, isFalse);
      },
    );

    test('delivery completo manda cliente, zona y dirección', () async {
      final p = conVenta();
      p.elegirEntrega(EntregaCaja.delivery);
      p.elegirZona(_centro);
      p.escribirCliente(' Ana ');
      p.escribirTelefono('987654321');
      p.escribirDireccion('Av. Lima 1');
      p.cobrarAlEntregarActivo(true);

      final r = await p.cobrar();

      expect(r.tipo, TipoCobroCaja.exito);
      final s = repo.pedidas.single;
      expect(s.cliente.nombre, 'Ana');
      expect(s.zona, 'Centro');
      expect(s.deliveryCentavos, 300);
      expect(s.totalCentavos, 1200);
      expect(s.cobrarAlEntregar, isTrue);
    });

    test(
      'falta de stock: no se cobra, el carrito y el id se conservan',
      () async {
        final p = conVenta();
        repo.respuesta = const ResultadoVentaMostrador(
          faltas: [FaltaStock(nombre: 'Gaseosa Inca', pide: 2, hay: 1)],
        );

        final r = await p.cobrar();

        expect(r.tipo, TipoCobroCaja.bloqueado);
        expect(r.mensaje, contains('Gaseosa Inca (pides 2, hay 1)'));
        expect(p.carrito.vacio, isFalse);
        expect(p.idVenta, 'id-1');
      },
    );

    test(
      'precio que cambió: avisa el total nuevo y conserva el carrito',
      () async {
        final p = conVenta();
        repo.respuesta = const ResultadoVentaMostrador(
          precioCambio: true,
          totalActualCentavos: 1000,
          lineasCambiadas: ['Gaseosa Inca'],
        );

        final r = await p.cobrar();

        expect(r.tipo, TipoCobroCaja.bloqueado);
        expect(r.mensaje, contains('S/ 10,00'));
        expect(p.carrito.vacio, isFalse);
      },
    );

    test(
      'sin conexión: error, y reintentar usa el MISMO id (no cobra dos veces)',
      () async {
        final p = conVenta();
        repo.falla = Exception('sin red');

        final fallo = await p.cobrar();
        repo.falla = null;
        final reintento = await p.cobrar();

        expect(fallo.tipo, TipoCobroCaja.error);
        expect(reintento.tipo, TipoCobroCaja.exito);
        expect(repo.pedidas.map((s) => s.idVenta), ['id-1', 'id-1']);
      },
    );

    test(
      '«ya registrada» (otro toque llegó antes) limpia sin cobrar de nuevo',
      () async {
        final p = conVenta();
        repo.respuesta = const ResultadoVentaMostrador(yaRegistrada: true);

        final r = await p.cobrar();

        expect(r.tipo, TipoCobroCaja.yaRegistrada);
        expect(r.registrada, isTrue);
        expect(p.carrito.vacio, isTrue);
      },
    );

    test('con las ventas bloqueadas no cobra', () async {
      final p = conVenta();
      p.bloquearVentas(true);

      final r = await p.cobrar();

      expect(p.puedeCobrar, isFalse);
      expect(r.tipo, TipoCobroCaja.ignorado);
      expect(repo.pedidas, isEmpty);
      p.bloquearVentas(false);
      expect(p.puedeCobrar, isTrue);
    });

    test('sin forma de pago no se puede cobrar', () {
      final p = crear(pagos: const []);
      p.agregarProducto(productoSimple(), cantidad: 1);

      expect(p.puedeCobrar, isFalse);
    });

    test('avisa a la pantalla en cada cambio', () async {
      final p = conVenta();
      var avisos = 0;
      p.addListener(() => avisos++);

      await p.cobrar();

      expect(avisos, greaterThanOrEqualTo(2), reason: 'cobrando y terminado');
    });
  });

  group(
    'de punta a punta con el repositorio real (simulador de Firestore)',
    () {
      late FakeFirebaseFirestore db;

      Future<void> guardar(Producto p) => db
          .collection('negocios')
          .doc(_negocio)
          .collection('productos')
          .doc(p.id)
          .set(
            ProductoFirestoreMapper.paraFirestore(p)..['negocioId'] = _negocio,
          );

      test(
        'el queso y las gaseosas se cobran en el local y el stock baja',
        () async {
          db = FakeFirebaseFirestore();
          await guardar(quesoPorMedida(stockBase: 3200));
          await guardar(productoSimple(stock: 24, precioCentavos: 450));
          final p = VentaCajaProvider(
            negocioId: _negocio,
            registrar: RegistrarVentaMostrador(
              VentasMostradorRepository(db: db, reloj: () => _ahora),
            ),
            opcionesPago: const [_efectivo],
            generarId: () => 'venta-${DateTime.now().microsecondsSinceEpoch}',
          );
          p.agregarProducto(quesoPorMedida(), cantidad: 350);
          p.agregarProducto(productoSimple(precioCentavos: 450), cantidad: 2);

          final r = await p.cobrar();

          expect(r.tipo, TipoCobroCaja.exito);
          expect(r.totalCentavos, 1740);
          final queso = await db
              .collection('negocios')
              .doc(_negocio)
              .collection('productos')
              .doc('queso')
              .get();
          expect(queso.data()!['stockBase'], 2850);
          final gaseosa = await db
              .collection('negocios')
              .doc(_negocio)
              .collection('productos')
              .doc('gaseosa')
              .get();
          expect(gaseosa.data()!['vendidos'], 1);
          expect(p.carrito.vacio, isTrue);
        },
      );
    },
  );
}
