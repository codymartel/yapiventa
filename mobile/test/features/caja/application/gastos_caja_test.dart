import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/textos_entrega_caja.dart';
import 'package:mobile/features/caja/application/services/validacion_gasto_caja.dart';
import 'package:mobile/features/caja/application/use_cases/gastos_caja.dart';
import 'package:mobile/features/caja/domain/models/dia_caja.dart';
import 'package:mobile/features/caja/domain/models/gasto_caja.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/caja/domain/repositories/repositorios_gastos_caja.dart';
import 'package:mobile/features/pedidos/domain/models/contadores_dia.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';

class _RepoFalso implements RepositorioGastosCaja {
  final List<GastoCaja> guardados = [];
  final List<String> anulados = [];
  bool yaEstaba = false;

  @override
  Future<bool> registrar(String negocioId, GastoCaja gasto) async {
    guardados.add(gasto);
    return !yaEstaba;
  }

  @override
  Future<ResultadoAnularGasto> anular(String negocioId, String gastoId) async {
    anulados.add(gastoId);
    return const ResultadoAnularGasto();
  }
}

void main() {
  group('TextosEntregaCaja', () {
    test('restaurante: en mesa, para llevar y delivery', () {
      String de(EntregaCaja e) =>
          TextosEntregaCaja.etiqueta(e, rubro: ' Restaurante ');

      expect(de(EntregaCaja.local), 'En mesa');
      expect(de(EntregaCaja.recojo), 'Para llevar');
      expect(de(EntregaCaja.delivery), 'Delivery');
    });

    test('los demás rubros: en tienda, recojo y delivery', () {
      for (final rubro in ['Bodega', 'Ropa', 'Belleza', 'Otros', '']) {
        expect(
          TextosEntregaCaja.etiqueta(EntregaCaja.local, rubro: rubro),
          'En tienda',
        );
        expect(
          TextosEntregaCaja.etiqueta(EntregaCaja.recojo, rubro: rubro),
          'Recojo',
        );
      }
    });

    test('la ayuda del cliente cambia con la entrega y el rubro', () {
      expect(
        TextosEntregaCaja.ayudaCliente(EntregaCaja.local, rubro: 'Restaurante'),
        'Mesa o nombre (opcional)',
      );
      expect(
        TextosEntregaCaja.ayudaCliente(EntregaCaja.recojo, rubro: 'Bodega'),
        'Nombre (opcional)',
      );
      expect(
        TextosEntregaCaja.ayudaCliente(EntregaCaja.delivery, rubro: 'Bodega'),
        'Nombre del cliente',
      );
    });
  });

  group('ValidacionGastoCaja', () {
    test('lee el monto escrito en céntimos enteros', () {
      expect(ValidacionGastoCaja.montoDeTexto('10'), 1000);
      expect(ValidacionGastoCaja.montoDeTexto('10,5'), 1050);
      expect(ValidacionGastoCaja.montoDeTexto('0.75'), 75);
      expect(ValidacionGastoCaja.montoDeTexto(''), isNull);
      expect(ValidacionGastoCaja.montoDeTexto('diez'), isNull);
      expect(ValidacionGastoCaja.montoDeTexto('1,234'), isNull);
    });

    test('dice qué falta', () {
      String? r(int? monto, {String pago = 'efectivo', String nota = ''}) =>
          ValidacionGastoCaja.revisar(
            montoCentavos: monto,
            metodoPago: pago,
            nota: nota,
          );

      expect(r(1000), isNull);
      expect(r(null), 'Escribe cuánto se gastó.');
      expect(r(0), 'El monto debe ser mayor que cero.');
      expect(r(10000000), isNull, reason: 'S/ 100 000,00 es el tope');
      expect(r(10000001), contains('demasiado grande'));
      expect(r(1000, pago: ' '), 'Elige de dónde salió la plata.');
      expect(r(1000, nota: 'x' * 120), isNull);
      expect(r(1000, nota: 'x' * 121), contains('muy larga'));
    });
  });

  group('GastosDia y DiaCaja', () {
    test('sumar y restar un gasto deja el día como estaba', () {
      const vacio = GastosDia.vacio;

      final con = vacio
          .mas(centavos: 1000, pago: 'efectivo', motivo: 'comida')
          .mas(centavos: 350, pago: 'yape', motivo: 'pasaje');

      expect(con.totalCentavos, 1350);
      expect(con.cantidad, 2);
      expect(con.porPago, {'efectivo': 1000, 'yape': 350});
      expect(con.porMotivo, {'comida': 1000, 'pasaje': 350});

      final sin = con
          .menos(centavos: 1000, pago: 'efectivo', motivo: 'comida')
          .menos(centavos: 350, pago: 'yape', motivo: 'pasaje');

      expect(sin.totalCentavos, 0);
      expect(sin.cantidad, 0);
      expect(sin.porPago, isEmpty, reason: 'lo que llega a 0 se quita');
      expect(sin.porMotivo, isEmpty);
    });

    test('restar de más no baja de cero', () {
      final g = GastosDia.vacio.menos(
        centavos: 500,
        pago: 'efectivo',
        motivo: 'otro',
      );

      expect(g.totalCentavos, 0);
      expect(g.cantidad, 0);
      expect(g.porPago, isEmpty);
    });

    test('efectivo en caja = vendido en efectivo − gastado en efectivo', () {
      const dia = DiaCaja(
        ventas: ResumenVentasDia(
          dia: '2026-11-11',
          ventasCentavos: 30000,
          contadores: ContadoresDia(
            porPago: {'efectivo': 20000, 'yape': 10000},
          ),
        ),
        gastos: GastosDia(
          totalCentavos: 1500,
          cantidad: 2,
          porPago: {'efectivo': 1000, 'yape': 500},
        ),
      );

      expect(dia.efectivoCentavos, 19000);
      expect(dia.quedaCentavos, 28500);
      expect(dia.gastosCentavos, 1500);
    });

    test('si se gastó más de lo vendido, lo que queda es negativo', () {
      const dia = DiaCaja(
        ventas: ResumenVentasDia(dia: '2026-11-11'),
        gastos: GastosDia(totalCentavos: 1000, porPago: {'efectivo': 1000}),
      );

      expect(dia.quedaCentavos, -1000);
      expect(dia.efectivoCentavos, -1000);
    });
  });

  group('casos de uso de gastos', () {
    late _RepoFalso repo;
    // 03:30 UTC del 12 = 22:30 del 11 en Lima.
    final noche = DateTime.utc(2026, 11, 12, 3, 30);

    setUp(() => repo = _RepoFalso());

    test(
      'guarda en el día de Lima, con la clave del pago y la nota limpia',
      () async {
        final registrar = RegistrarGastoCaja(repo, reloj: () => noche);

        final r = await registrar(
          negocioId: 'n1',
          idGasto: ' g1 ',
          montoCentavos: 1000,
          motivo: MotivoGasto.comida,
          metodoPago: 'Efectivo',
          nota: '  almuerzo ',
        );

        expect(r.ok, isTrue);
        expect(r.yaGuardado, isFalse);
        final g = repo.guardados.single;
        expect(g.id, 'g1');
        expect(g.dia, '2026-11-11');
        expect(g.metodoPago, 'efectivo');
        expect(g.nota, 'almuerzo');
        expect(g.montoCentavos, 1000);
      },
    );

    test('un dato inválido no llega al repositorio', () async {
      final registrar = RegistrarGastoCaja(repo, reloj: () => noche);

      final r = await registrar(
        negocioId: 'n1',
        idGasto: 'g1',
        montoCentavos: 0,
        motivo: MotivoGasto.otro,
        metodoPago: 'efectivo',
      );

      expect(r.ok, isFalse);
      expect(r.error, 'El monto debe ser mayor que cero.');
      expect(repo.guardados, isEmpty);
    });

    test('un toque repetido avisa que ya estaba guardado', () async {
      repo.yaEstaba = true;
      final registrar = RegistrarGastoCaja(repo, reloj: () => noche);

      final r = await registrar(
        negocioId: 'n1',
        idGasto: 'g1',
        montoCentavos: 1000,
        motivo: MotivoGasto.comida,
        metodoPago: 'efectivo',
      );

      expect(r.ok, isTrue);
      expect(r.yaGuardado, isTrue);
    });

    test('anular pide un id y llama al repositorio', () async {
      final anular = AnularGastoCaja(repo);

      await anular(negocioId: 'n1', gastoId: 'g1');

      expect(repo.anulados, ['g1']);
      expect(() => anular(negocioId: 'n1', gastoId: ' '), throwsArgumentError);
    });

    test('un motivo desconocido se lee como «Otro»', () {
      expect(MotivoGasto.desdeId('pasaje'), MotivoGasto.pasaje);
      expect(MotivoGasto.desdeId('fiesta'), MotivoGasto.otro);
    });
  });
}
