import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/use_cases/gastos_caja.dart';
import 'package:mobile/features/caja/domain/models/dia_caja.dart';
import 'package:mobile/features/caja/domain/models/gasto_caja.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/caja/domain/repositories/repositorios_gastos_caja.dart';
import 'package:mobile/features/caja/presentation/providers/dia_caja_provider.dart';
import 'package:mobile/features/caja/presentation/providers/gasto_caja_provider.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';

const _efectivo = OpcionPagoCaja(id: 'efectivo', etiqueta: 'Efectivo');
const _yape = OpcionPagoCaja(id: 'yape', etiqueta: 'Yape');

class _RepoGastos implements RepositorioGastosCaja {
  final List<GastoCaja> guardados = [];
  final List<String> anulados = [];
  Object? falla;
  bool yaAnulado = false;
  Completer<void>? espera;

  @override
  Future<bool> registrar(String negocioId, GastoCaja gasto) async {
    if (espera != null) await espera!.future;
    if (falla != null) throw falla!;
    final repetido = guardados.any((g) => g.id == gasto.id);
    if (!repetido) guardados.add(gasto);
    return !repetido;
  }

  @override
  Future<ResultadoAnularGasto> anular(String negocioId, String gastoId) async {
    if (falla != null) throw falla!;
    anulados.add(gastoId);
    return ResultadoAnularGasto(yaAnulado: yaAnulado);
  }
}

class _RepoDia implements RepositorioDiaCaja {
  final Map<String, StreamController<DiaCaja>> canales = {};
  final List<String> pedidos = [];

  @override
  Stream<DiaCaja> escuchar(String negocioId, String dia) {
    pedidos.add(dia);
    return (canales[dia] = StreamController<DiaCaja>()).stream;
  }
}

void main() {
  group('GastoCajaProvider', () {
    late _RepoGastos repo;
    var contador = 0;

    GastoCajaProvider crear() {
      contador = 0;
      return GastoCajaProvider(
        negocioId: 'n1',
        registrar: RegistrarGastoCaja(
          repo,
          reloj: () => DateTime.utc(2026, 11, 11, 17),
        ),
        anular: AnularGastoCaja(repo),
        opcionesPago: const [_efectivo, _yape],
        generarId: () => 'g-${++contador}',
      );
    }

    setUp(() => repo = _RepoGastos());

    test('empieza vacío: comida, primer pago y sin poder guardar', () {
      final p = crear();

      expect(p.motivo, MotivoGasto.comida);
      expect(p.pago, _efectivo);
      expect(p.puedeGuardar, isFalse);
      expect(p.motivoNoGuardar, isNull, reason: 'aún no escribió nada');
      expect(p.idGasto, 'g-1');
    });

    test('un monto mal escrito dice por qué no se puede guardar', () {
      final p = crear();

      p.escribirMonto('0');
      expect(p.puedeGuardar, isFalse);
      expect(p.motivoNoGuardar, 'El monto debe ser mayor que cero.');

      p.escribirMonto('10');
      expect(p.montoCentavos, 1000);
      expect(p.puedeGuardar, isTrue);
      expect(p.motivoNoGuardar, isNull);

      p.elegirPago(null);
      expect(p.motivoNoGuardar, 'Elige de dónde salió la plata.');
    });

    test('guardar S/ 10 de comida avisa, limpia y estrena id', () async {
      final p = crear();
      p.escribirMonto('10');
      p.escribirNota('almuerzo');

      final r = await p.guardar();

      expect(r.ok, isTrue);
      expect(r.mensaje, 'Gasto guardado · Comida · S/ 10,00');
      expect(r.gastoId, 'g-1');
      final g = repo.guardados.single;
      expect(g.montoCentavos, 1000);
      expect(g.metodoPago, 'efectivo');
      expect(g.dia, '2026-11-11');
      expect(p.montoTexto, isEmpty);
      expect(p.nota, isEmpty);
      expect(p.idGasto, 'g-2');
      expect(p.pago, _efectivo, reason: 'la forma de pago se conserva');
    });

    test(
      'si falla, conserva lo escrito y el id: reintentar no duplica',
      () async {
        final p = crear();
        p.escribirMonto('7,50');
        p.elegirMotivo(MotivoGasto.pasaje);
        repo.falla = Exception('sin red');

        final mal = await p.guardar();

        expect(mal.ok, isFalse);
        expect(mal.mensaje, contains('no se guardará dos veces'));
        expect(p.montoTexto, '7,50');
        expect(p.idGasto, 'g-1');

        repo.falla = null;
        final bien = await p.guardar();

        expect(bien.ok, isTrue);
        expect(repo.guardados.single.id, 'g-1');
        expect(repo.guardados.single.montoCentavos, 750);
      },
    );

    test('un doble toque guarda una sola vez', () async {
      final p = crear();
      p.escribirMonto('10');
      repo.espera = Completer<void>();

      final primero = p.guardar();
      final segundo = await p.guardar();
      repo.espera!.complete();
      await primero;

      expect(segundo.ok, isFalse);
      expect(repo.guardados, hasLength(1));
    });

    test('anular avisa según lo que pasó', () async {
      final p = crear();

      expect((await p.anular('g-1')).mensaje, 'Gasto anulado.');

      repo.yaAnulado = true;
      expect((await p.anular('g-1')).mensaje, 'Ese gasto ya estaba anulado.');

      repo.falla = Exception('sin red');
      final r = await p.anular('g-1');
      expect(r.ok, isFalse);
      expect(r.mensaje, contains('No se pudo anular'));
    });
  });

  group('DiaCajaProvider', () {
    late _RepoDia repo;
    var ahora = DateTime.utc(2026, 11, 11, 17);

    DiaCajaProvider crear() =>
        DiaCajaProvider(negocioId: 'n1', repositorio: repo, reloj: () => ahora);

    DiaCaja dia(String clave, int ventas) => DiaCaja(
      ventas: ResumenVentasDia(dia: clave, ventasCentavos: ventas),
    );

    setUp(() {
      repo = _RepoDia();
      ahora = DateTime.utc(2026, 11, 11, 17);
    });

    test('escucha el día de hoy en Lima y muestra lo que llega', () async {
      final p = crear();
      var avisos = 0;
      p.addListener(() => avisos++);

      p.iniciar();
      expect(p.cargando, isTrue);
      expect(p.dia.ventasCentavos, 0);
      expect(repo.pedidos, ['2026-11-11']);

      repo.canales['2026-11-11']!.add(dia('2026-11-11', 1740));
      await Future<void>.delayed(Duration.zero);

      expect(p.cargando, isFalse);
      expect(p.enVivo, isTrue);
      expect(p.dia.ventasCentavos, 1740);
      expect(avisos, greaterThanOrEqualTo(2));
      p.dispose();
    });

    test('pasada la medianoche de Lima cambia al día nuevo', () async {
      final p = crear();
      p.iniciar();

      p.revisarDia();
      expect(repo.pedidos, hasLength(1), reason: 'mismo día: no reescucha');

      // 05:10 UTC del 12 = 00:10 del 12 en Lima.
      ahora = DateTime.utc(2026, 11, 12, 5, 10);
      p.revisarDia();

      expect(repo.pedidos, ['2026-11-11', '2026-11-12']);
      expect(
        repo.canales['2026-11-11']!.hasListener,
        isFalse,
        reason: 'la escucha vieja se cerró',
      );
      p.dispose();
    });

    test('un error se muestra y se puede reintentar', () async {
      final p = crear();
      p.iniciar();

      repo.canales['2026-11-11']!.addError(Exception('sin permiso'));
      await Future<void>.delayed(Duration.zero);

      expect(p.error, isTrue);
      expect(p.enVivo, isFalse);

      p.reintentar();
      expect(p.error, isFalse);
      expect(repo.pedidos, hasLength(2));
      p.dispose();
    });

    test('al cerrarse deja de escuchar', () {
      final p = crear();
      p.iniciar();

      p.dispose();

      expect(repo.canales['2026-11-11']!.hasListener, isFalse);
    });
  });
}
