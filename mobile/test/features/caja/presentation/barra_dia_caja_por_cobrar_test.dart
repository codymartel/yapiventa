import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/textos_dia_caja.dart';
import 'package:mobile/features/caja/domain/models/dia_caja.dart';
import 'package:mobile/features/caja/domain/repositories/repositorios_gastos_caja.dart';
import 'package:mobile/features/caja/presentation/providers/dia_caja_provider.dart';
import 'package:mobile/features/caja/presentation/widgets/barra_dia_caja.dart';
import 'package:mobile/features/pedidos/domain/models/contadores_dia.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';

/// Hoy: 3 ventas en el local en efectivo (S/ 100,00) y un delivery de
/// S/ 40,00 entregado sin cobrar.
DiaCaja _dia({int porCobrar = 4000}) => DiaCaja(
  ventas: ResumenVentasDia(
    dia: '2026-11-05',
    ventasCentavos: 14000,
    entregados: 4,
    contadores: ContadoresDia(
      mostradorCentavos: 14000,
      mostrador: 4,
      porPago: const {'efectivo': 10000},
      porCobrarCentavos: porCobrar,
      porCobrar: porCobrar > 0 ? 1 : 0,
    ),
  ),
);

class _RepoFijo implements RepositorioDiaCaja {
  _RepoFijo(this.dia);

  final DiaCaja dia;

  @override
  Stream<DiaCaja> escuchar(String negocioId, String clave) => Stream.value(dia);
}

void main() {
  group('números del día', () {
    test('el efectivo solo cuenta lo cobrado', () {
      expect(_dia().efectivoCentavos, 10000);
      expect(_dia().porCobrarCentavos, 4000);
    });

    test('nota de ventas en PC: dice lo que falta cobrar', () {
      expect(
        TextosDiaCaja.notaVentas(_dia()),
        '4 ventas · S/ 40,00 por cobrar',
      );
      expect(TextosDiaCaja.notaVentas(_dia(porCobrar: 0)), '4 ventas');
    });
  });

  group('barra', () {
    Future<void> abrir(
      WidgetTester t,
      DiaCaja dia,
      EstiloDiaCaja estilo,
    ) async {
      final provider = DiaCajaProvider(
        negocioId: 'n1',
        repositorio: _RepoFijo(dia),
        reloj: () => DateTime.utc(2026, 11, 5, 17),
      )..iniciar();
      addTearDown(provider.dispose);
      await t.binding.setSurfaceSize(const Size(1300, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: BarraDiaCaja(provider: provider, estilo: estilo),
            ),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('tarjetas: «Por cobrar» junto a local y tienda web', (t) async {
      await abrir(t, _dia(), EstiloDiaCaja.tarjetas);

      expect(find.text('Por cobrar'), findsOneWidget);
      expect(find.text('S/ 40,00'), findsOneWidget);
      expect(find.text('S/ 100,00'), findsOneWidget, reason: 'efectivo');
    });

    testWidgets('tarjetas: sin nada pendiente, no aparece', (t) async {
      await abrir(t, _dia(porCobrar: 0), EstiloDiaCaja.tarjetas);

      expect(find.text('Por cobrar'), findsNothing);
    });

    testWidgets('tablero de PC: en la nota de «Ventas de hoy»', (t) async {
      await abrir(t, _dia(), EstiloDiaCaja.tablero);

      expect(find.text('4 ventas · S/ 40,00 por cobrar'), findsOneWidget);
    });

    testWidgets('fila delgada: un chip más solo si hay pendiente', (t) async {
      await abrir(t, _dia(), EstiloDiaCaja.fila);
      expect(find.textContaining('Por cobrar', findRichText: true), findsOne);

      await abrir(t, _dia(porCobrar: 0), EstiloDiaCaja.fila);
      expect(
        find.textContaining('Por cobrar', findRichText: true),
        findsNothing,
      );
    });
  });
}
