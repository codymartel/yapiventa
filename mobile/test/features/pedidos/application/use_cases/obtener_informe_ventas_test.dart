import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/periodo_informe.dart';
import 'package:mobile/features/pedidos/application/use_cases/obtener_informe_ventas.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_resumenes_ventas.dart';

class _Repo implements RepositorioResumenesVentas {
  final List<(String, String, String)> consultas = [];
  final Map<String, ResumenVentasDia> guardados = {};

  @override
  Future<List<ResumenVentasDia>> obtenerResumenes(
    String negocioId,
    String desde,
    String hasta,
  ) async {
    consultas.add((negocioId, desde, hasta));
    return [
      for (final r in guardados.values)
        if (r.dia.compareTo(desde) >= 0 && r.dia.compareTo(hasta) <= 0) r,
    ];
  }
}

void main() {
  final jueves = DateTime.utc(2026, 11, 5, 19, 32);
  late _Repo repo;
  late ObtenerInformeVentas caso;

  setUp(() {
    repo = _Repo();
    caso = ObtenerInformeVentas(repo);
    repo.guardados['2026-11-05'] = const ResumenVentasDia(
      dia: '2026-11-05',
      ventasCentavos: 3000,
      entregados: 3,
    );
    repo.guardados['2026-11-04'] = const ResumenVentasDia(
      dia: '2026-11-04',
      ventasCentavos: 2000,
      entregados: 4,
    );
  });

  test('hoy hace dos consultas (hoy y ayer) y compara', () async {
    final r = await caso(negocioId: 'n1', tipo: TipoPeriodo.hoy, ahora: jueves);

    expect(repo.consultas, [
      ('n1', '2026-11-05', '2026-11-05'),
      ('n1', '2026-11-04', '2026-11-04'),
    ]);
    expect(r.actual.ventasCentavos, 3000);
    expect(r.anterior!.ventasCentavos, 2000);
    expect(r.ventas!.porcentaje, 50);
  });

  test('sin comparar hace una sola consulta', () async {
    final r = await caso(
      negocioId: 'n1',
      tipo: TipoPeriodo.semana,
      ahora: jueves,
      comparar: false,
    );

    expect(repo.consultas, [('n1', '2026-10-30', '2026-11-05')]);
    expect(r.anterior, isNull);
    expect(r.actual.ventasCentavos, 5000);
    expect(r.actual.mejorDia!.dia, '2026-11-05');
  });

  test('un día elegido inválido es un error de programación', () async {
    await expectLater(
      caso(negocioId: 'n1', tipo: TipoPeriodo.dia, ahora: jueves, dia: 'ayer'),
      throwsArgumentError,
    );
    expect(repo.consultas, isEmpty);
  });
}
