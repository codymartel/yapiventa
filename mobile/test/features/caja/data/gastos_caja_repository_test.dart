import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/data/dia_caja_repository.dart';
import 'package:mobile/features/caja/data/gastos_caja_repository.dart';
import 'package:mobile/features/caja/domain/models/gasto_caja.dart';

const _negocio = 'n1';
const _dia = '2026-11-11';

GastoCaja _gasto({
  String id = 'g1',
  int monto = 1000,
  MotivoGasto motivo = MotivoGasto.comida,
  String pago = 'efectivo',
  String nota = '',
}) {
  return GastoCaja(
    id: id,
    montoCentavos: monto,
    motivo: motivo,
    metodoPago: pago,
    dia: _dia,
    nota: nota,
  );
}

void main() {
  late FakeFirebaseFirestore db;
  late GastosCajaRepository repo;

  Future<Map<String, dynamic>?> resumen() async =>
      (await db.doc('negocios/$_negocio/resumenes/$_dia').get()).data();

  Future<Map<String, dynamic>?> gasto(String id) async =>
      (await db.doc('negocios/$_negocio/gastos/$id').get()).data();

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = GastosCajaRepository(db: db);
  });

  group('registrar', () {
    test('guarda el gasto y lo suma al resumen de su día', () async {
      final nuevo = await repo.registrar(_negocio, _gasto(nota: 'almuerzo'));

      expect(nuevo, isTrue);
      final g = (await gasto('g1'))!;
      expect(g['montoCentavos'], 1000);
      expect(g['motivo'], 'comida');
      expect(g['metodoPago'], 'efectivo');
      expect(g['dia'], _dia);
      expect(g['nota'], 'almuerzo');
      expect(g['anulado'], isFalse);
      expect(g['fecha'], isNotNull);

      final r = (await resumen())!;
      expect(r['gastosCentavos'], 1000);
      expect(r['gastos'], 1);
      expect(r['porGastoPago'], {'efectivo': 1000});
      expect(r['porGastoMotivo'], {'comida': 1000});
    });

    test('dos gastos se acumulan por pago y por motivo', () async {
      await repo.registrar(_negocio, _gasto());
      await repo.registrar(
        _negocio,
        _gasto(id: 'g2', monto: 350, motivo: MotivoGasto.pasaje, pago: 'yape'),
      );
      await repo.registrar(_negocio, _gasto(id: 'g3', monto: 500));

      final r = (await resumen())!;
      expect(r['gastosCentavos'], 1850);
      expect(r['gastos'], 3);
      expect(r['porGastoPago'], {'efectivo': 1500, 'yape': 350});
      expect(r['porGastoMotivo'], {'comida': 1500, 'pasaje': 350});
    });

    test('no toca las ventas que ya tenía el resumen', () async {
      await db.doc('negocios/$_negocio/resumenes/$_dia').set({
        'ventasCentavos': 30000,
        'entregados': 4,
        'porPago': {'efectivo': 30000},
      });

      await repo.registrar(_negocio, _gasto());

      final r = (await resumen())!;
      expect(r['ventasCentavos'], 30000);
      expect(r['entregados'], 4);
      expect(r['porPago'], {'efectivo': 30000});
      expect(r['gastosCentavos'], 1000);
    });

    test('un toque repetido con el mismo id no suma dos veces', () async {
      await repo.registrar(_negocio, _gasto());

      final otraVez = await repo.registrar(_negocio, _gasto());

      expect(otraVez, isFalse);
      final r = (await resumen())!;
      expect(r['gastosCentavos'], 1000);
      expect(r['gastos'], 1);
    });

    test('rechaza un monto de cero, un id vacío y un negocio vacío', () {
      expect(
        () => repo.registrar(_negocio, _gasto(monto: 0)),
        throwsArgumentError,
      );
      expect(
        () => repo.registrar(_negocio, _gasto(id: ' ')),
        throwsArgumentError,
      );
      expect(() => repo.registrar(' ', _gasto()), throwsStateError);
    });
  });

  group('anular', () {
    test('lo marca anulado (no lo borra) y lo resta del día', () async {
      await repo.registrar(_negocio, _gasto());
      await repo.registrar(
        _negocio,
        _gasto(id: 'g2', monto: 350, motivo: MotivoGasto.pasaje, pago: 'yape'),
      );

      final r = await repo.anular(_negocio, 'g1');

      expect(r.yaAnulado, isFalse);
      final g = (await gasto('g1'))!;
      expect(g['anulado'], isTrue);
      expect(g['montoCentavos'], 1000, reason: 'el gasto sigue ahí');
      final res = (await resumen())!;
      expect(res['gastosCentavos'], 350);
      expect(res['gastos'], 1);
      expect(res['porGastoPago'], {
        'efectivo': 0,
        'yape': 350,
      }, reason: 'lo anulado queda en 0 (al leer se descarta)');
      expect(res['porGastoMotivo'], {'comida': 0, 'pasaje': 350});

      final leido = await DiaCajaRepository(
        db: db,
      ).escuchar(_negocio, _dia).first;
      expect(leido.gastos.porPago, {'yape': 350});
      expect(leido.gastos.porMotivo, {'pasaje': 350});
    });

    test('anular dos veces resta una sola vez', () async {
      await repo.registrar(_negocio, _gasto());
      await repo.registrar(_negocio, _gasto(id: 'g2', monto: 500));
      await repo.anular(_negocio, 'g1');

      final otraVez = await repo.anular(_negocio, 'g1');

      expect(otraVez.yaAnulado, isTrue);
      expect((await resumen())!['gastosCentavos'], 500);
    });

    test('un gasto que no existe no toca nada', () async {
      final r = await repo.anular(_negocio, 'fantasma');

      expect(r.yaAnulado, isTrue);
      expect(await resumen(), isNull);
    });

    test('resta del día en que se guardó, no de otro', () async {
      await repo.registrar(_negocio, _gasto());
      await db.doc('negocios/$_negocio/resumenes/2026-11-12').set({
        'gastosCentavos': 700,
        'gastos': 1,
      });

      await repo.anular(_negocio, 'g1');

      final otroDia =
          (await db.doc('negocios/$_negocio/resumenes/2026-11-12').get())
              .data()!;
      expect(otroDia['gastosCentavos'], 700);
      expect((await resumen())!['gastosCentavos'], 0);
    });
  });

  group('DiaCajaRepository', () {
    test('de UN documento saca ventas y gastos, y avisa los cambios', () async {
      final dia = DiaCajaRepository(db: db);
      final vistos = <(int, int, int)>[];
      final escucha = dia
          .escuchar(_negocio, _dia)
          .listen(
            (d) => vistos.add((
              d.ventasCentavos,
              d.gastosCentavos,
              d.efectivoCentavos,
            )),
          );
      await Future<void>.delayed(Duration.zero);

      await db.doc('negocios/$_negocio/resumenes/$_dia').set({
        'ventasCentavos': 30000,
        'entregados': 4,
        'porPago': {'efectivo': 20000, 'yape': 10000},
      });
      await repo.registrar(_negocio, _gasto());
      await Future<void>.delayed(Duration.zero);
      await escucha.cancel();

      expect(vistos.first, (0, 0, 0), reason: 'un día sin documento es cero');
      expect(vistos.last, (30000, 1000, 19000));
    });

    test('un resumen raro se lee como cero, sin romper', () async {
      await db.doc('negocios/$_negocio/resumenes/$_dia').set({
        'gastosCentavos': -50,
        'gastos': 'dos',
        'porGastoPago': 'efectivo',
        'porGastoMotivo': {'comida': -3, 'pasaje': 200},
      });

      final d = await DiaCajaRepository(db: db).escuchar(_negocio, _dia).first;

      expect(d.gastos.totalCentavos, 0);
      expect(d.gastos.cantidad, 0);
      expect(d.gastos.porPago, isEmpty);
      expect(d.gastos.porMotivo, {'pasaje': 200});
    });

    test('sin negocio no escucha', () {
      expect(
        () => DiaCajaRepository(db: db).escuchar(' ', _dia),
        throwsStateError,
      );
    });
  });
}
