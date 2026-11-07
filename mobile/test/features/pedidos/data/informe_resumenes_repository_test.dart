import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late VentasMostradorRepository repo;

  Future<void> guardar(String negocio, String dia, int ventas) {
    return db
        .collection('negocios')
        .doc(negocio)
        .collection('resumenes')
        .doc(dia)
        .set({'ventasCentavos': ventas, 'entregados': 1});
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = VentasMostradorRepository(db: db);
    await guardar('n1', '2026-10-31', 100);
    await guardar('n1', '2026-11-01', 200);
    await guardar('n1', '2026-11-03', 300);
    await guardar('n1', '2026-11-05', 400);
    await guardar('n1', '2026-11-06', 500);
    await guardar('otro', '2026-11-03', 999);
  });

  test('trae solo los días del rango, incluidos los dos extremos', () async {
    final r = await repo.obtenerResumenes('n1', '2026-11-01', '2026-11-05');

    expect(r.map((e) => e.dia).toList()..sort(), [
      '2026-11-01',
      '2026-11-03',
      '2026-11-05',
    ]);
    expect(r.fold<int>(0, (s, e) => s + e.ventasCentavos), 900);
  });

  test('un rango sin ventas devuelve una lista vacía', () async {
    expect(
      await repo.obtenerResumenes('n1', '2026-11-07', '2026-11-09'),
      isEmpty,
    );
  });

  test('no mezcla los resúmenes de otro negocio', () async {
    final r = await repo.obtenerResumenes('otro', '2026-11-01', '2026-11-30');

    expect(r.single.ventasCentavos, 999);
  });

  test('un rango inválido, al revés o de más de 31 días se rechaza', () {
    for (final (d, h) in [
      ('ayer', '2026-11-05'),
      ('2026-11-05', '2026-11-01'),
      ('2026-10-01', '2026-11-05'),
    ]) {
      expect(
        () => repo.obtenerResumenes('n1', d, h),
        throwsArgumentError,
        reason: '$d a $h',
      );
    }
  });

  test('exactamente 31 días se permite', () async {
    final r = await repo.obtenerResumenes('n1', '2026-10-06', '2026-11-05');

    expect(r, hasLength(4));
  });

  test('sin negocioId no opera', () {
    expect(
      () => repo.obtenerResumenes(' ', '2026-11-01', '2026-11-05'),
      throwsStateError,
    );
  });
}
