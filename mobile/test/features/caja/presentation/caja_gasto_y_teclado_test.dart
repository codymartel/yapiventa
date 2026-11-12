import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/domain/models/gasto_caja.dart';
import 'package:mobile/features/caja/presentation/widgets/caja_contextual_panel.dart';

import '../helpers/banco_caja_flow.dart';

void main() {
  late BancoCaja banco;

  setUp(() => banco = BancoCaja());

  Future<void> abrirGasto(WidgetTester t) async {
    await t.tap(find.text('Gasto'));
    await t.pumpAndSettle();
  }

  group('gasto rápido', () {
    testWidgets('S/ 10 de comida: se guarda, avisa y se puede anular', (
      t,
    ) async {
      await banco.abrir(t);
      await abrirGasto(t);

      expect(find.text('¿Cuánto se gastó?'), findsOneWidget);
      expect(find.text('Guardar gasto'), findsOneWidget);
      for (final m in MotivoGasto.values) {
        expect(find.text(m.etiqueta), findsOneWidget);
      }

      await t.enterText(banco.campoHoja(0), '10');
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar gasto · S/ 10,00'));
      await t.pumpAndSettle();

      final g = banco.gastos.guardados.single;
      expect(g.montoCentavos, 1000);
      expect(g.motivo, MotivoGasto.comida);
      expect(g.metodoPago, 'efectivo');
      expect(g.dia, '2026-11-11');
      expect(find.text('Gasto guardado · Comida · S/ 10,00'), findsOneWidget);

      await t.tap(find.text('Anular'));
      await t.pumpAndSettle();
      expect(banco.gastos.anulados, [g.id]);
      expect(find.text('Gasto anulado.'), findsOneWidget);
    });

    testWidgets('elige motivo, de dónde salió y nota', (t) async {
      await banco.abrir(t);
      await abrirGasto(t);

      await t.enterText(banco.campoHoja(0), '7,5');
      await t.tap(find.text('Pasaje'));
      await t.tap(find.text('Yape'));
      await t.enterText(banco.campoHoja(banco.camposHoja - 1), 'taxi');
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar gasto · S/ 7,50'));
      await t.pumpAndSettle();

      final g = banco.gastos.guardados.single;
      expect(g.montoCentavos, 750);
      expect(g.motivo, MotivoGasto.pasaje);
      expect(g.metodoPago, 'yape');
      expect(g.nota, 'taxi');
    });

    testWidgets('con 0 no deja guardar y dice por qué', (t) async {
      await banco.abrir(t);
      await abrirGasto(t);

      await t.enterText(banco.campoHoja(0), '0');
      await t.pumpAndSettle();

      expect(find.text('El monto debe ser mayor que cero.'), findsOneWidget);
      await t.tap(find.text('Guardar gasto'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(banco.gastos.guardados, isEmpty);
    });

    testWidgets('solo acepta cifras con hasta 2 decimales', (t) async {
      await banco.abrir(t);
      await abrirGasto(t);

      await t.enterText(banco.campoHoja(0), '12,345');
      await t.pumpAndSettle();

      expect(
        t.widget<TextField>(banco.campoHoja(0)).controller!.text,
        '12,34',
        reason: 'el tercer decimal no entra',
      );
      expect(find.text('Guardar gasto · S/ 12,34'), findsOneWidget);
    });

    testWidgets('si falla, lo dice en la hoja y conserva lo escrito', (
      t,
    ) async {
      await banco.abrir(t);
      await abrirGasto(t);
      banco.gastos.falla = Exception('sin red');

      await t.enterText(banco.campoHoja(0), '10');
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar gasto · S/ 10,00'));
      await t.pumpAndSettle();

      expect(find.textContaining('no se guardará dos veces'), findsOneWidget);
      expect(find.text('¿Cuánto se gastó?'), findsOneWidget);
      expect(find.text('Guardar gasto · S/ 10,00'), findsOneWidget);
    });

    testWidgets('en PC se abre como diálogo', (t) async {
      await banco.abrir(t, ancho: 1280, alto: 800);
      await abrirGasto(t);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('¿Cuánto se gastó?'), findsOneWidget);
    });
  });

  group('ayuda', () {
    testWidgets('«¿Cómo funciona?» explica la venta, el día y el gasto', (
      t,
    ) async {
      await banco.abrir(t);

      await t.tap(find.byTooltip('¿Cómo funciona?'));
      await t.pumpAndSettle();

      expect(find.byType(ContenidoAyudaCaja), findsOneWidget);
      expect(find.text('Efectivo en caja'), findsWidgets);
      expect(find.text('Botón «Gasto»'), findsOneWidget);

      await t.tap(find.text('Cerrar'));
      await t.pumpAndSettle();
      expect(find.byType(ContenidoAyudaCaja), findsNothing);
    });

    testWidgets('el panel de ayuda cabe en 320 px', (t) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(child: CajaContextualPanel()),
          ),
        ),
      );

      expect(find.text('¿Cómo funciona?'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('teclado abierto y pantalla de lado: nada se aplasta', () {
    /// El alto de un campo de texto NO debe encogerse con el teclado.
    double altoCampo(WidgetTester t) => t.getSize(banco.campoHoja(0)).height;

    for (final (nombre, ancho, alto, teclado) in const [
      ('celular vertical', 390.0, 780.0, 320.0),
      ('celular chico vertical', 320.0, 568.0, 260.0),
      ('celular de lado', 812.0, 375.0, 200.0),
      ('celular chico de lado', 568.0, 320.0, 170.0),
      ('tableta de lado', 1024.0, 768.0, 380.0),
    ]) {
      testWidgets('gasto en $nombre con teclado', (t) async {
        await banco.abrir(t, ancho: ancho, alto: alto);
        await abrirGasto(t);
        final antes = altoCampo(t);

        await banco.teclado(t, teclado);

        expect(t.takeException(), isNull, reason: 'sin desbordes');
        expect(altoCampo(t), antes, reason: 'el campo no se encoge');
        final campo = t.getRect(banco.campoHoja(0));
        expect(
          campo.bottom,
          lessThanOrEqualTo(alto - teclado),
          reason: 'el campo queda sobre el teclado',
        );

        await banco.teclado(t, 0);
        expect(t.takeException(), isNull, reason: 'al cerrar vuelve bien');
        expect(find.text('¿Cuánto se gastó?'), findsOneWidget);
      });

      testWidgets('venta con delivery en $nombre con teclado', (t) async {
        await banco.abrir(t, ancho: ancho, alto: alto);
        await banco.agregar(t, 'Gaseosa Inca');
        final verVenta = find.textContaining('Ver venta');
        if (verVenta.evaluate().isNotEmpty) {
          await t.tap(verVenta);
          await t.pumpAndSettle();
        }
        await t.ensureVisible(find.text('Delivery'));
        await t.tap(find.text('Delivery'));
        await t.pumpAndSettle();

        await banco.teclado(t, teclado);

        expect(t.takeException(), isNull, reason: 'sin desbordes');
        expect(find.textContaining('Cobrar'), findsWidgets);

        await banco.teclado(t, 0);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('girar el teléfono con el gasto abierto no pierde lo escrito', (
      t,
    ) async {
      await banco.abrir(t);
      await abrirGasto(t);
      await t.enterText(banco.campoHoja(0), '10');
      await t.pumpAndSettle();

      t.view.physicalSize = const Size(780, 390);
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('Guardar gasto · S/ 10,00'), findsOneWidget);
    });
  });
}
