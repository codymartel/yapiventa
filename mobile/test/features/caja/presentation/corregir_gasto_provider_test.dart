import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/textos_gastos_caja.dart';
import 'package:mobile/features/caja/application/services/validacion_gasto_caja.dart';
import 'package:mobile/features/caja/application/use_cases/gastos_caja.dart';
import 'package:mobile/features/caja/domain/models/gasto_caja.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/caja/domain/repositories/repositorios_gastos_caja.dart';
import 'package:mobile/features/caja/presentation/providers/gasto_caja_provider.dart';
import 'package:mobile/features/caja/presentation/providers/gastos_de_hoy_provider.dart';

// Corregir un gasto: el caso de uso, el formulario lleno (GastoCajaProvider
// corrigiendo), la lista «Gastos de hoy» y sus textos.

const _efectivo = OpcionPagoCaja(id: 'efectivo', etiqueta: 'Efectivo');
const _yape = OpcionPagoCaja(id: 'yape', etiqueta: 'Yape');

GastoCaja _gasto({
  String id = 'g1',
  int monto = 10000,
  MotivoGasto motivo = MotivoGasto.mercaderia,
  String pago = 'efectivo',
  String nota = '',
  DateTime? fecha,
  bool anulado = false,
}) {
  return GastoCaja(
    id: id,
    montoCentavos: monto,
    motivo: motivo,
    metodoPago: pago,
    dia: '2026-11-11',
    nota: nota,
    fecha: fecha,
    anulado: anulado,
  );
}

class _Repo implements RepositorioGastosCaja, RepositorioGastosDelDia {
  final List<(String, GastoCaja)> corregidos = [];
  final List<String> anulados = [];
  ResultadoCorregirGasto resultado = ResultadoCorregirGasto.corregido;
  Object? falla;
  List<GastoCaja> deHoy = [];
  String diaPedido = '';

  @override
  Future<bool> registrar(String negocioId, GastoCaja gasto) async => true;

  @override
  Future<ResultadoAnularGasto> anular(String negocioId, String gastoId) async {
    if (falla != null) throw falla!;
    anulados.add(gastoId);
    return const ResultadoAnularGasto();
  }

  @override
  Future<ResultadoCorregirGasto> corregir(
    String negocioId, {
    required String viejoId,
    required GastoCaja correcto,
  }) async {
    if (falla != null) throw falla!;
    corregidos.add((viejoId, correcto));
    return resultado;
  }

  @override
  Future<List<GastoCaja>> delDia(
    String negocioId,
    String dia, {
    int limite = 20,
  }) async {
    diaPedido = dia;
    if (falla != null) throw falla!;
    return deHoy;
  }
}

void main() {
  late _Repo repo;

  setUp(() => repo = _Repo());

  group('CorregirGastoCaja', () {
    Future<ResultadoCorregirGastoCaja> corregir({
      GastoCaja? original,
      int? monto = 1000,
      MotivoGasto motivo = MotivoGasto.mercaderia,
      String pago = 'efectivo',
      String id = 'g2',
    }) {
      return CorregirGastoCaja(repo)(
        negocioId: 'n1',
        original: original ?? _gasto(),
        idNuevo: id,
        montoCentavos: monto,
        motivo: motivo,
        metodoPago: pago,
      );
    }

    test('arma el correcto en el mismo día y lo manda a corregir', () async {
      final r = await corregir();

      expect(r.error, isNull);
      expect(r.resultado, ResultadoCorregirGasto.corregido);
      final (viejo, correcto) = repo.corregidos.single;
      expect(viejo, 'g1');
      expect(correcto.id, 'g2');
      expect(correcto.montoCentavos, 1000);
      expect(correcto.dia, '2026-11-11');
    });

    test('no corrige un gasto ya anulado', () async {
      final r = await corregir(original: _gasto(anulado: true));

      expect(r.error, 'Este gasto ya está anulado.');
      expect(repo.corregidos, isEmpty);
    });

    test('sin cambios no hay nada que corregir', () async {
      final r = await corregir(monto: 10000);

      expect(r.error, contains('Cambia'));
      expect(repo.corregidos, isEmpty);
    });

    test('valida el monto como un gasto nuevo', () async {
      expect((await corregir(monto: null)).error, isNotNull);
      expect((await corregir(monto: 0)).error, isNotNull);
      expect(repo.corregidos, isEmpty);
    });

    test('el id nuevo no puede ser el del viejo', () {
      expect(() => corregir(id: 'g1'), throwsArgumentError);
    });
  });

  group('GastosDeHoyCaja', () {
    test('pide el día de Lima y pone el más nuevo arriba', () async {
      repo.deHoy = [
        _gasto(id: 'a', fecha: DateTime.utc(2026, 11, 11, 14)),
        _gasto(id: 'b', fecha: DateTime.utc(2026, 11, 11, 18)),
        _gasto(id: 'c'),
      ];
      // 02:00 UTC del 12 = 21:00 del 11 en Lima.
      final leer = GastosDeHoyCaja(
        repo,
        reloj: () => DateTime.utc(2026, 11, 12, 2),
      );

      final gastos = await leer('n1');

      expect(repo.diaPedido, '2026-11-11');
      expect(gastos.map((g) => g.id), ['c', 'b', 'a']);
    });
  });

  group('GastoCajaProvider corrigiendo', () {
    GastoCajaProvider crear(GastoCaja original) {
      var n = 0;
      return GastoCajaProvider.corrigiendo(
        negocioId: 'n1',
        original: original,
        corregir: CorregirGastoCaja(repo),
        anular: AnularGastoCaja(repo),
        registrar: RegistrarGastoCaja(repo),
        opcionesPago: const [_efectivo, _yape],
        generarId: () => 'nuevo${n++}',
      );
    }

    test('llega lleno con el gasto y no deja guardar sin cambios', () {
      final p = crear(_gasto(nota: 'cajas'));

      expect(p.corrigiendo, isTrue);
      expect(p.montoTexto, '100');
      expect(p.motivo, MotivoGasto.mercaderia);
      expect(p.pago, _efectivo);
      expect(p.nota, 'cajas');
      expect(p.puedeGuardar, isFalse);
      expect(p.motivoNoGuardar, contains('Cambia'));
    });

    test(
      'S/ 100 → S/ 10: guarda la corrección y dice el monto nuevo',
      () async {
        final p = crear(_gasto());
        p.escribirMonto('10');

        final r = await p.guardar();

        expect(r.ok, isTrue);
        expect(r.mensaje, 'Gasto corregido · ahora es S/ 10,00');
        expect(r.viejoAnulado, isTrue);
        expect(r.gasto!.montoCentavos, 1000);
        expect(repo.corregidos.single.$1, 'g1');
      },
    );

    test(
      'sin conexión conserva el id: reintentar no corrige dos veces',
      () async {
        final p = crear(_gasto());
        p.escribirMonto('10');
        repo.falla = Exception('sin red');

        final r1 = await p.guardar();
        repo.falla = null;
        final r2 = await p.guardar();

        expect(r1.ok, isFalse);
        expect(r1.mensaje, contains('corrección'));
        expect(r2.ok, isTrue);
        expect(r2.gasto!.id, 'nuevo0');
      },
    );

    test('si ya estaba anulado lo dice y no se toma como éxito', () async {
      repo.resultado = ResultadoCorregirGasto.yaAnulado;
      final p = crear(_gasto());
      p.escribirMonto('10');

      final r = await p.guardar();

      expect(r.ok, isFalse);
      expect(r.viejoAnulado, isTrue);
      expect(r.mensaje, contains('ya estaba anulado'));
    });

    test('una forma de pago que ya no está activa queda sin elegir', () {
      final p = crear(_gasto(pago: 'plin'));

      expect(p.pago, isNull);
      expect(p.puedeGuardar, isFalse);
    });
  });

  group('GastosDeHoyProvider', () {
    test('carga una vez y tras corregir tacha el viejo y suma el correcto '
        'sin volver a leer', () async {
      repo.deHoy = [_gasto(), _gasto(id: 'g0', monto: 500)];
      final p = GastosDeHoyProvider(
        negocioId: 'n1',
        leer: GastosDeHoyCaja(repo),
      );
      await p.cargar();
      repo.deHoy = [];

      p.aplicar(
        'g1',
        ResultadoGastoCaja(
          ok: true,
          mensaje: 'Gasto corregido · ahora es S/ 10,00',
          gasto: _gasto(id: 'g2', monto: 1000),
          viejoAnulado: true,
        ),
      );

      expect(p.gastos.map((g) => g.id), ['g2', 'g1', 'g0']);
      expect(p.gastos[1].anulado, isTrue);
      expect(p.gastos[2].anulado, isFalse);
      expect(p.ultimoCambio, 'Gasto corregido · ahora es S/ 10,00');
      expect(p.ultimoOk, isTrue);
    });

    test('sin conexión queda en error y se puede reintentar', () async {
      repo.falla = Exception('sin red');
      final p = GastosDeHoyProvider(
        negocioId: 'n1',
        leer: GastosDeHoyCaja(repo),
      );
      await p.cargar();
      expect(p.error, isTrue);

      repo.falla = null;
      repo.deHoy = [_gasto()];
      await p.cargar();
      expect(p.error, isFalse);
      expect(p.gastos, hasLength(1));
    });

    test('avisa cuando llegó al tope de 20', () async {
      repo.deHoy = [for (var i = 0; i < 20; i++) _gasto(id: 'g$i')];
      final p = GastosDeHoyProvider(
        negocioId: 'n1',
        leer: GastosDeHoyCaja(repo),
      );
      await p.cargar();

      expect(p.hayMas, isTrue);
    });
  });

  group('textos', () {
    test('el monto vuelve al campo con coma y sin ceros de más', () {
      expect(ValidacionGastoCaja.textoDeMonto(10000), '100');
      expect(ValidacionGastoCaja.textoDeMonto(750), '7,50');
      expect(ValidacionGastoCaja.textoDeMonto(5), '0,05');
      expect(ValidacionGastoCaja.textoDeMonto(0), '');
      for (final c in [1, 99, 100, 1234, 10000000]) {
        expect(
          ValidacionGastoCaja.montoDeTexto(ValidacionGastoCaja.textoDeMonto(c)),
          c,
        );
      }
    });

    test('la línea chica: hora de Lima, forma de pago, nota y anulado', () {
      final g = _gasto(
        fecha: DateTime.utc(2026, 11, 11, 14, 40),
        pago: 'yape',
        nota: 'cajas',
        anulado: true,
      );

      expect(
        TextosGastosCaja.detalle(g, const [_efectivo, _yape]),
        '9:40 · Yape · cajas · anulado',
      );
      expect(TextosGastosCaja.hora(_gasto()), 'ahora');
      expect(TextosGastosCaja.pago(_gasto(pago: 'plin'), const []), 'Plin');
      expect(
        TextosGastosCaja.antes(g, 'S/ 100,00'),
        'Antes: S/ 100,00 · Mercadería · 9:40',
      );
    });
  });
}
