import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/data/dia_caja_repository.dart';
import 'package:mobile/features/caja/data/gastos_caja_mapper.dart';
import 'package:mobile/features/caja/data/gastos_caja_repository.dart';
import 'package:mobile/features/caja/domain/models/gasto_caja.dart';
import 'package:mobile/features/caja/domain/repositories/repositorios_gastos_caja.dart';

// Corregir un gasto mal anotado (S/ 100 en vez de S/ 10) y leer los gastos
// del día. Corregir = anular el viejo + crear el correcto + ajustar el
// resumen, en UNA transacción.

const _negocio = 'n1';
const _dia = '2026-11-11';

GastoCaja _gasto({
  String id = 'g1',
  int monto = 10000,
  MotivoGasto motivo = MotivoGasto.mercaderia,
  String pago = 'efectivo',
  String dia = _dia,
  String nota = '',
}) {
  return GastoCaja(
    id: id,
    montoCentavos: monto,
    motivo: motivo,
    metodoPago: pago,
    dia: dia,
    nota: nota,
  );
}

void main() {
  late FakeFirebaseFirestore db;
  late GastosCajaRepository repo;

  Future<Map<String, dynamic>?> resumen([String dia = _dia]) async =>
      (await db.doc('negocios/$_negocio/resumenes/$dia').get()).data();

  Future<Map<String, dynamic>?> gasto(String id) async =>
      (await db.doc('negocios/$_negocio/gastos/$id').get()).data();

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = GastosCajaRepository(db: db);
  });

  group('corregir', () {
    test('S/ 100 → S/ 10: el viejo queda anulado, nace el correcto y el día '
        'queda en S/ 10', () async {
      await repo.registrar(_negocio, _gasto());
      await repo.registrar(
        _negocio,
        _gasto(id: 'g0', monto: 500, motivo: MotivoGasto.pasaje),
      );

      final r = await repo.corregir(
        _negocio,
        viejoId: 'g1',
        correcto: _gasto(id: 'g2', monto: 1000),
      );

      expect(r, ResultadoCorregirGasto.corregido);
      final viejo = (await gasto('g1'))!;
      expect(viejo['anulado'], isTrue);
      expect(viejo['anuladoEn'], isNotNull);
      expect(viejo['montoCentavos'], 10000, reason: 'el viejo no se edita');
      final nuevo = (await gasto('g2'))!;
      expect(nuevo['montoCentavos'], 1000);
      expect(nuevo['anulado'], isFalse);
      expect(nuevo['dia'], _dia);

      final dia = GastosCajaMapper.gastosDiaDesdeFirestore(await resumen());
      expect(dia.totalCentavos, 1500, reason: 'S/ 10 + el pasaje de S/ 5');
      expect(dia.cantidad, 2, reason: 'se anuló uno y nació otro');
      expect(dia.porPago, {'efectivo': 1500});
      expect(dia.porMotivo, {'mercaderia': 1000, 'pasaje': 500});
    });

    test(
      'cambiar de dónde salió y el motivo mueve la plata de clave',
      () async {
        await repo.registrar(_negocio, _gasto());

        await repo.corregir(
          _negocio,
          viejoId: 'g1',
          correcto: _gasto(
            id: 'g2',
            monto: 1000,
            motivo: MotivoGasto.comida,
            pago: 'yape',
          ),
        );

        final r = (await resumen())!;
        expect(r['gastosCentavos'], 1000);
        expect(r['gastos'], 1);
        // La clave vieja queda en 0 (no se quita) y al leer se descarta.
        expect(r['porGastoPago'], {'efectivo': 0, 'yape': 1000});
        expect(r['porGastoMotivo'], {'mercaderia': 0, 'comida': 1000});
      },
    );

    test('las ventas del resumen no se tocan', () async {
      await db.doc('negocios/$_negocio/resumenes/$_dia').set({
        'ventasCentavos': 30000,
        'entregados': 4,
        'porPago': {'efectivo': 30000},
      });
      await repo.registrar(_negocio, _gasto());

      await repo.corregir(
        _negocio,
        viejoId: 'g1',
        correcto: _gasto(id: 'g2', monto: 1000),
      );

      final r = (await resumen())!;
      expect(r['ventasCentavos'], 30000);
      expect(r['entregados'], 4);
      expect(r['porPago'], {'efectivo': 30000});
      expect(r['gastosCentavos'], 1000);
    });

    test('un gasto ya anulado no se corrige y nada cambia', () async {
      await repo.registrar(_negocio, _gasto());
      await repo.anular(_negocio, 'g1');
      final antes = await resumen();

      final r = await repo.corregir(
        _negocio,
        viejoId: 'g1',
        correcto: _gasto(id: 'g2', monto: 1000),
      );

      expect(r, ResultadoCorregirGasto.yaAnulado);
      expect(await gasto('g2'), isNull);
      expect(await resumen(), antes);
    });

    test('un toque repetido no corrige dos veces', () async {
      await repo.registrar(_negocio, _gasto());
      final correcto = _gasto(id: 'g2', monto: 1000);

      await repo.corregir(_negocio, viejoId: 'g1', correcto: correcto);
      final r = await repo.corregir(
        _negocio,
        viejoId: 'g1',
        correcto: correcto,
      );

      expect(r, ResultadoCorregirGasto.yaCorregido);
      final dia = GastosCajaMapper.gastosDiaDesdeFirestore(await resumen());
      expect(dia.totalCentavos, 1000);
      expect(dia.cantidad, 1);
    });

    test('un gasto que no existe no crea nada', () async {
      final r = await repo.corregir(
        _negocio,
        viejoId: 'nada',
        correcto: _gasto(id: 'g2', monto: 1000),
      );

      expect(r, ResultadoCorregirGasto.yaAnulado);
      expect(await gasto('g2'), isNull);
      expect(await resumen(), isNull);
    });

    test(
      'el correcto va al día del viejo (un solo resumen se ajusta)',
      () async {
        await repo.registrar(_negocio, _gasto());

        await repo.corregir(
          _negocio,
          viejoId: 'g1',
          correcto: _gasto(id: 'g2', monto: 1000, dia: '2026-11-12'),
        );

        expect((await gasto('g2'))!['dia'], _dia);
        expect(await resumen('2026-11-12'), isNull);
        expect((await resumen())!['gastosCentavos'], 1000);
      },
    );

    test('datos inválidos se rechazan antes de escribir', () {
      expect(
        () => repo.corregir(
          _negocio,
          viejoId: 'g1',
          correcto: _gasto(id: 'g1', monto: 1000),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.corregir(
          _negocio,
          viejoId: 'g1',
          correcto: _gasto(id: 'g2', monto: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.corregir(
          ' ',
          viejoId: 'g1',
          correcto: _gasto(id: 'g2', monto: 1000),
        ),
        throwsStateError,
      );
    });
  });

  group('gastos del día', () {
    test(
      'trae los del día, anulados incluidos, y no los de otro día',
      () async {
        final leer = DiaCajaRepository(db: db);
        await repo.registrar(_negocio, _gasto());
        await repo.registrar(_negocio, _gasto(id: 'g2', monto: 500));
        await repo.anular(_negocio, 'g2');
        await repo.registrar(_negocio, _gasto(id: 'g3', dia: '2026-11-10'));

        final gastos = await leer.delDia(_negocio, _dia);

        expect(gastos.map((g) => g.id).toSet(), {'g1', 'g2'});
        expect(gastos.firstWhere((g) => g.id == 'g2').anulado, isTrue);
        expect(gastos.firstWhere((g) => g.id == 'g1').montoCentavos, 10000);
      },
    );

    test('respeta el tope', () async {
      final leer = DiaCajaRepository(db: db);
      for (var i = 0; i < 5; i++) {
        await repo.registrar(_negocio, _gasto(id: 'g$i'));
      }

      expect(await leer.delDia(_negocio, _dia, limite: 3), hasLength(3));
    });
  });
}
