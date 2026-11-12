import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/domain/models/gasto_caja.dart';

import '../helpers/banco_caja_flow.dart';

// «Gastos de hoy» y «Corregir» dentro de Caja: se abre tocando «Gastos» en
// los números del día, los anulados se ven tachados y corregir abre el
// formulario lleno. En celular, de lado, con teclado y en PC.

GastoCaja _gasto({
  String id = 'g1',
  int monto = 10000,
  MotivoGasto motivo = MotivoGasto.mercaderia,
  String pago = 'efectivo',
  int hora = 14,
  bool anulado = false,
}) {
  return GastoCaja(
    id: id,
    montoCentavos: monto,
    motivo: motivo,
    metodoPago: pago,
    dia: '2026-11-11',
    fecha: DateTime.utc(2026, 11, 11, hora, 40),
    anulado: anulado,
  );
}

void main() {
  late BancoCaja banco;

  setUp(() {
    banco = BancoCaja();
    banco.gastos.deHoy = [
      _gasto(),
      _gasto(id: 'g0', monto: 500, motivo: MotivoGasto.pasaje, hora: 13),
      _gasto(
        id: 'gx',
        monto: 300,
        motivo: MotivoGasto.comida,
        hora: 12,
        anulado: true,
      ),
    ];
  });

  /// Toca «Gastos» en los números del día (tarjeta o fila delgada).
  Future<void> abrirLista(WidgetTester t) async {
    // De lado, la fila delgada se desliza a los costados: primero se lleva
    // «Gastos» a la vista.
    final gastos = find.textContaining('Gastos', findRichText: true).first;
    await t.ensureVisible(gastos);
    await t.pumpAndSettle();
    await t.tap(gastos);
    await t.pumpAndSettle();
  }

  TextStyle? estilo(WidgetTester t, String texto) =>
      t.widget<Text>(find.text(texto).first).style;

  group('Gastos de hoy', () {
    testWidgets('se abre desde «Gastos», lee una vez y tacha los anulados', (
      t,
    ) async {
      await banco.abrir(t);
      await abrirLista(t);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Gastos de hoy'), findsOneWidget);
      expect(banco.gastos.lecturasDeHoy, 1);
      expect(find.text('Mercadería'), findsOneWidget);
      expect(find.text('S/ 100,00'), findsOneWidget);
      expect(find.text('9:40 · Efectivo'), findsOneWidget);
      expect(find.text('Corregir'), findsNWidgets(2), reason: 'no en anulados');
      expect(find.text('7:40 · Efectivo · anulado'), findsOneWidget);
      expect(estilo(t, 'S/ 3,00')?.decoration, TextDecoration.lineThrough);
      expect(estilo(t, 'S/ 100,00')?.decoration, isNull);
    });

    testWidgets('sin gastos lo dice', (t) async {
      banco.gastos.deHoy = [];
      await banco.abrir(t);
      await abrirLista(t);

      expect(find.text('Hoy no anotaste gastos.'), findsOneWidget);
    });

    testWidgets('sin conexión lo dice y deja reintentar', (t) async {
      banco.gastos.falla = Exception('sin red');
      await banco.abrir(t);
      await abrirLista(t);

      expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
      banco.gastos.falla = null;
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(find.text('Mercadería'), findsOneWidget);
    });

    testWidgets('en PC se abre como diálogo', (t) async {
      await banco.abrir(t, ancho: 1280, alto: 800);
      await abrirLista(t);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Gastos de hoy'), findsOneWidget);
    });
  });

  group('Corregir', () {
    Future<void> corregirPrimero(WidgetTester t) async {
      await t.tap(find.text('Corregir').first);
      await t.pumpAndSettle();
    }

    testWidgets('S/ 100 → S/ 10: el formulario llega lleno y la lista se '
        'actualiza sin volver a leer', (t) async {
      await banco.abrir(t);
      await abrirLista(t);
      await corregirPrimero(t);

      expect(find.text('Corregir gasto'), findsOneWidget);
      expect(find.text('Antes: S/ 100,00 · Mercadería · 9:40'), findsOneWidget);
      expect(banco.campoHoja(0), findsOneWidget);
      expect(t.widget<TextField>(banco.campoHoja(0)).controller!.text, '100');

      await t.enterText(banco.campoHoja(0), '10');
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar corrección · S/ 10,00'));
      await t.pumpAndSettle();

      final (viejo, correcto) = banco.gastos.corregidos.single;
      expect(viejo, 'g1');
      expect(correcto.montoCentavos, 1000);
      expect(correcto.motivo, MotivoGasto.mercaderia);
      expect(correcto.dia, '2026-11-11');

      // De vuelta en la lista: el viejo tachado y el correcto arriba.
      expect(find.text('Corregir gasto'), findsNothing);
      expect(find.text('Gasto corregido · ahora es S/ 10,00'), findsOneWidget);
      expect(estilo(t, 'S/ 100,00')?.decoration, TextDecoration.lineThrough);
      expect(find.text('S/ 10,00'), findsOneWidget);
      expect(banco.gastos.lecturasDeHoy, 1, reason: 'no se vuelve a leer');
    });

    testWidgets('sin cambios no deja guardar y lo explica', (t) async {
      await banco.abrir(t);
      await abrirLista(t);
      await corregirPrimero(t);

      expect(find.textContaining('Cambia el monto'), findsOneWidget);
      await t.tap(find.text('Guardar corrección · S/ 100,00'));
      await t.pumpAndSettle();
      expect(banco.gastos.corregidos, isEmpty);
    });

    testWidgets('«Anular este gasto» pide un segundo toque', (t) async {
      await banco.abrir(t);
      await abrirLista(t);
      await corregirPrimero(t);

      final anular = find.text('Anular este gasto (sin poner otro)');
      await t.ensureVisible(anular);
      await t.tap(anular);
      await t.pumpAndSettle();
      expect(banco.gastos.anulados, isEmpty);

      await t.tap(find.text('Toca otra vez para anularlo'));
      await t.pumpAndSettle();
      expect(banco.gastos.anulados, ['g1']);
      expect(find.text('Gasto anulado.'), findsOneWidget);
      expect(estilo(t, 'S/ 100,00')?.decoration, TextDecoration.lineThrough);
      expect(find.text('Corregir'), findsOneWidget);
    });

    for (final (nombre, ancho, alto, teclado) in const [
      ('celular vertical', 390.0, 780.0, 320.0),
      ('celular chico vertical', 320.0, 568.0, 260.0),
      ('celular de lado', 812.0, 375.0, 200.0),
      ('celular chico de lado', 568.0, 320.0, 170.0),
    ]) {
      testWidgets('lista y corregir en $nombre con teclado', (t) async {
        await banco.abrir(t, ancho: ancho, alto: alto);
        await abrirLista(t);
        expect(t.takeException(), isNull, reason: 'la lista cabe');

        await corregirPrimero(t);
        final antes = t.getSize(banco.campoHoja(0)).height;
        await banco.teclado(t, teclado);

        expect(t.takeException(), isNull, reason: 'sin desbordes');
        expect(t.getSize(banco.campoHoja(0)).height, antes);
        expect(
          t.getRect(banco.campoHoja(0)).bottom,
          lessThanOrEqualTo(alto - teclado),
          reason: 'el monto queda sobre el teclado',
        );
        expect(
          find.textContaining('Guardar corrección'),
          findsOneWidget,
          reason: 'el botón principal sigue ahí',
        );

        await banco.teclado(t, 0);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('girar con la corrección abierta no pierde lo escrito', (
      t,
    ) async {
      await banco.abrir(t);
      await abrirLista(t);
      await corregirPrimero(t);
      await t.enterText(banco.campoHoja(0), '10');
      await t.pumpAndSettle();

      t.view.physicalSize = const Size(780, 390);
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('Guardar corrección · S/ 10,00'), findsOneWidget);
    });
  });
}
