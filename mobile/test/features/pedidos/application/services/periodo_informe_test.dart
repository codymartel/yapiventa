import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/periodo_informe.dart';

// 19:32 UTC = 14:32 en Lima.
PeriodoInforme _de(TipoPeriodo tipo, DateTime ahora, {String? dia}) =>
    PeriodoInforme.de(tipo, ahora, dia: dia);

void main() {
  final jueves = DateTime.utc(2026, 11, 5, 19, 32);

  test('hoy se compara con ayer', () {
    final p = _de(TipoPeriodo.hoy, jueves);
    expect([p.desde, p.hasta], ['2026-11-05', '2026-11-05']);
    expect([p.anteriorDesde, p.anteriorHasta], ['2026-11-04', '2026-11-04']);
  });

  test('el día es el de Lima, no el de UTC', () {
    // 02:00 UTC del 6 = 21:00 del 5 en Lima.
    final p = _de(TipoPeriodo.hoy, DateTime.utc(2026, 11, 6, 2));
    expect(p.hasta, '2026-11-05');
  });

  test('semana = los últimos 7 días contra los 7 de antes', () {
    final p = _de(TipoPeriodo.semana, jueves);
    expect([p.desde, p.hasta], ['2026-10-30', '2026-11-05']);
    expect([p.anteriorDesde, p.anteriorHasta], ['2026-10-23', '2026-10-29']);
  });

  test('la semana cruza el cambio de año', () {
    final p = _de(TipoPeriodo.semana, DateTime.utc(2027, 1, 3, 15));
    expect([p.desde, p.hasta], ['2026-12-28', '2027-01-03']);
    expect([p.anteriorDesde, p.anteriorHasta], ['2026-12-21', '2026-12-27']);
  });

  test('mes = del 1 hasta hoy contra el mismo tramo del mes anterior', () {
    final p = _de(TipoPeriodo.mes, jueves);
    expect([p.desde, p.hasta], ['2026-11-01', '2026-11-05']);
    expect([p.anteriorDesde, p.anteriorHasta], ['2026-10-01', '2026-10-05']);
  });

  test('el mes anterior más corto no se pasa de su último día', () {
    // 31 de marzo contra febrero de 2026 (28 días).
    final p = _de(TipoPeriodo.mes, DateTime.utc(2026, 3, 31, 15));
    expect([p.desde, p.hasta], ['2026-03-01', '2026-03-31']);
    expect([p.anteriorDesde, p.anteriorHasta], ['2026-02-01', '2026-02-28']);
  });

  test('enero se compara con diciembre del año anterior', () {
    final p = _de(TipoPeriodo.mes, DateTime.utc(2027, 1, 10, 15));
    expect([p.anteriorDesde, p.anteriorHasta], ['2026-12-01', '2026-12-10']);
  });

  test('un día elegido se compara con el día anterior', () {
    final p = _de(TipoPeriodo.dia, jueves, dia: '2026-11-01');
    expect([p.desde, p.hasta], ['2026-11-01', '2026-11-01']);
    expect([p.anteriorDesde, p.anteriorHasta], ['2026-10-31', '2026-10-31']);
  });

  test('un día elegido inválido, inexistente o futuro se rechaza', () {
    for (final dia in [null, '', '5/11/2026', '2026-02-30', '2026-11-06']) {
      expect(
        () => _de(TipoPeriodo.dia, jueves, dia: dia),
        throwsArgumentError,
        reason: '$dia',
      );
    }
  });

  test('ningún periodo pasa de 31 días', () {
    for (final tipo in TipoPeriodo.values) {
      final p = _de(tipo, jueves, dia: '2026-11-01');
      for (final (d, h) in [
        (p.desde, p.hasta),
        (p.anteriorDesde, p.anteriorHasta),
      ]) {
        final dias = DateTime.parse(h).difference(DateTime.parse(d)).inDays + 1;
        expect(dias, inInclusiveRange(1, 31), reason: '$tipo');
      }
    }
  });
}
