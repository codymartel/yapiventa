import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/textos_preparacion_catalogo.dart';
import 'package:mobile/features/caja/presentation/providers/preparacion_catalogo_provider.dart';
import 'package:mobile/features/caja/presentation/widgets/aviso_catalogo_sin_preparar.dart';
import 'package:mobile/features/caja/presentation/widgets/preparacion_catalogo_host.dart';
import 'package:mobile/features/productos/application/use_cases/preparar_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_relleno_catalogo.dart';

/// Un relleno que se puede dejar «en curso» para ver el estado de progreso.
class _Relleno implements RepositorioRellenoCatalogo {
  bool listo = false;
  Object? falla;
  ResultadoRelleno resultado = const ResultadoRelleno(
    actualizados: 36,
    yaCompletos: 2,
    total: 38,
  );
  Completer<void>? espera;
  int rellenos = 0;

  @override
  Future<bool> catalogoListo(String negocioId) async => listo;

  @override
  Future<ResultadoRelleno> rellenar(String negocioId) async {
    rellenos++;
    if (espera != null) await espera!.future;
    if (falla != null) throw falla!;
    return resultado;
  }
}

void main() {
  late _Relleno repo;
  late PreparacionCatalogoProvider provider;
  var listas = 0;
  final bloqueos = <bool>[];

  Future<void> abrir(
    WidgetTester tester, {
    double ancho = 390,
    double alto = 780,
  }) async {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PreparacionCatalogoHost(
            provider: provider,
            alQuedarLista: () => listas++,
            alCambiarBloqueo: bloqueos.add,
            child: Column(
              children: [
                const Text('Pantalla de Caja'),
                AvisoCatalogoSinPreparar(provider: provider),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = _Relleno();
    provider = PreparacionCatalogoProvider(
      negocioId: 'n1',
      preparar: PrepararCatalogoCaja(repo),
    );
    listas = 0;
    bloqueos.clear();
  });

  tearDown(() => provider.dispose());

  group('el aviso inicial', () {
    testWidgets('celular: hoja desde abajo con los tres puntos y dos botones', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Prepara tu catálogo para Caja'), findsOneWidget);
      expect(find.text('No cambia precios, fotos ni stock'), findsOneWidget);
      expect(find.text('Tarda unos segundos'), findsOneWidget);
      expect(find.text('Necesitas conexión a internet'), findsOneWidget);
      expect(find.text('Preparar ahora'), findsOneWidget);
      expect(find.text('Más tarde'), findsOneWidget);
      expect(repo.rellenos, 0, reason: 'nada se escribe sin el «sí»');
    });

    testWidgets('PC (1 100 px o más): diálogo centrado, no hoja', (
      tester,
    ) async {
      await abrir(tester, ancho: 1100, alto: 700);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Prepara tu catálogo para Caja'), findsOneWidget);
    });

    testWidgets('tableta (1 099 px) todavía es hoja, como el resto de Caja', (
      tester,
    ) async {
      await abrir(tester, ancho: 1099, alto: 700);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('si ya estaba preparado no aparece nada', (tester) async {
      repo.listo = true;

      await abrir(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Pantalla de Caja'), findsOneWidget);
      expect(find.text('Falta preparar tu catálogo'), findsNothing);
    });

    testWidgets('«Más tarde» cierra y deja el aviso ámbar en Caja', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('Más tarde'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Falta preparar tu catálogo'), findsOneWidget);
      expect(
        find.textContaining('no podrás buscar por nombre'),
        findsOneWidget,
      );
      expect(provider.estado, EstadoPreparacion.pospuesta);
      expect(repo.rellenos, 0);
    });

    testWidgets('cerrar con «atrás» equivale a «Más tarde»', (tester) async {
      await abrir(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(provider.estado, EstadoPreparacion.pospuesta);
      expect(find.text('Falta preparar tu catálogo'), findsOneWidget);
    });

    testWidgets('tocar fuera de la hoja equivale a «Más tarde»', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();

      expect(provider.estado, EstadoPreparacion.pospuesta);
    });
  });

  group('preparar', () {
    testWidgets(
      '«Preparar ahora»: progreso, sin poder cerrar, y luego «listo»',
      (tester) async {
        repo.espera = Completer<void>();
        await abrir(tester);

        await tester.tap(find.text('Preparar ahora'));
        await tester.pump();

        expect(find.text('Preparando tu catálogo…'), findsOneWidget);
        expect(find.text('Más tarde'), findsNothing);
        expect(provider.bloqueaVentas, isTrue);
        expect(bloqueos, [true]);

        // Atrás y tocar fuera no la cierran.
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.tapAt(const Offset(195, 40));
        await tester.pump();
        expect(find.text('Preparando tu catálogo…'), findsOneWidget);

        repo.espera!.complete();
        await tester.pumpAndSettle();

        expect(find.text('Catálogo listo'), findsOneWidget);
        expect(find.text('38 productos revisados'), findsOneWidget);
        expect(
          find.text('36 preparados · 2 ya estaban listos'),
          findsOneWidget,
        );
        expect(bloqueos, [true, false]);
        expect(listas, 1, reason: 'Caja recarga su lista una vez');
      },
    );

    testWidgets('«Empezar a vender» cierra y no vuelve a aparecer', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.text('Preparar ahora'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar a vender'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(provider.estado, EstadoPreparacion.noHaceFalta);
      expect(find.text('Falta preparar tu catálogo'), findsNothing);
    });

    testWidgets('cerrar el «listo» con atrás también termina el aviso', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.text('Preparar ahora'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(provider.estado, EstadoPreparacion.noHaceFalta);
    });

    testWidgets('un solo producto usa el singular', (tester) async {
      repo.resultado = const ResultadoRelleno(actualizados: 1, total: 1);
      await abrir(tester);

      await tester.tap(find.text('Preparar ahora'));
      await tester.pumpAndSettle();

      expect(find.text('1 producto revisado'), findsOneWidget);
      expect(find.text('1 preparado'), findsOneWidget);
    });

    testWidgets('en PC el mismo proceso ocurre dentro del diálogo', (
      tester,
    ) async {
      await abrir(tester, ancho: 1100, alto: 700);

      await tester.tap(find.text('Preparar ahora'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Catálogo listo'), findsOneWidget);
    });
  });

  group('errores', () {
    testWidgets('sin conexión: error en texto, «Reintentar» completa', (
      tester,
    ) async {
      repo.falla = Exception('sin red');
      await abrir(tester);

      await tester.tap(find.text('Preparar ahora'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo terminar'), findsOneWidget);
      expect(
        find.textContaining('Lo que ya se preparó se conserva'),
        findsOneWidget,
      );
      expect(provider.bloqueaVentas, isFalse);

      repo.falla = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Catálogo listo'), findsOneWidget);
    });

    testWidgets('error y «Más tarde»: queda el aviso ámbar', (tester) async {
      repo.falla = Exception('sin red');
      await abrir(tester);
      await tester.tap(find.text('Preparar ahora'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Más tarde'));
      await tester.pumpAndSettle();

      expect(find.text('Falta preparar tu catálogo'), findsOneWidget);
    });

    testWidgets('más de 500 productos: dice el límite y «Entendido» cierra', (
      tester,
    ) async {
      repo.resultado = const ResultadoRelleno(demasiados: true, total: 501);
      await abrir(tester);

      await tester.tap(find.text('Preparar ahora'));
      await tester.pumpAndSettle();

      expect(find.text('Tienes más de 500 productos'), findsOneWidget);
      expect(find.textContaining('Caja admite hasta 500'), findsOneWidget);
      expect(listas, 0, reason: 'no se preparó nada: no hay que recargar');

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Falta preparar tu catálogo'), findsOneWidget);
    });
  });

  group('desde el aviso fijo', () {
    testWidgets('«Preparar ahora» del aviso vuelve a abrir el proceso', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.text('Más tarde'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Preparar ahora'));
      await tester.pumpAndSettle();

      expect(find.text('Catálogo listo'), findsOneWidget);
      expect(repo.rellenos, 1);
      await tester.tap(find.text('Empezar a vender'));
      await tester.pumpAndSettle();
      expect(find.text('Falta preparar tu catálogo'), findsNothing);
    });
  });

  testWidgets('los botones miden al menos 48 px de alto', (tester) async {
    await abrir(tester);

    for (final texto in ['Preparar ahora', 'Más tarde']) {
      final boton = find.ancestor(
        of: find.text(texto),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(
        tester.getSize(boton).height,
        greaterThanOrEqualTo(48),
        reason: texto,
      );
    }
  });

  group('TextosPreparacionCatalogo', () {
    test('singular y plural', () {
      expect(TextosPreparacionCatalogo.revisados(1), '1 producto revisado');
      expect(TextosPreparacionCatalogo.revisados(38), '38 productos revisados');
    });

    test('el detalle suma lo preparado, lo que ya estaba y lo omitido', () {
      expect(
        TextosPreparacionCatalogo.detalle(
          const ResultadoRelleno(
            actualizados: 36,
            yaCompletos: 2,
            omitidos: 1,
            total: 39,
          ),
        ),
        '36 preparados · 2 ya estaban listos · 1 no se pudo revisar',
      );
      expect(
        TextosPreparacionCatalogo.detalle(
          const ResultadoRelleno(yaCompletos: 5, total: 5),
        ),
        '5 ya estaban listos',
      );
      expect(
        TextosPreparacionCatalogo.detalle(
          const ResultadoRelleno(yaCompletos: 1, total: 1),
        ),
        '1 ya estaba listo',
      );
    });

    test('sin productos dice que ya estarán listos', () {
      expect(
        TextosPreparacionCatalogo.detalle(const ResultadoRelleno()),
        contains('ya estarán listos'),
      );
    });
  });
}
