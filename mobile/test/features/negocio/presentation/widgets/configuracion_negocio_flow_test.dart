import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_content.dart';
import 'package:mobile/features/negocio/presentation/widgets/configuracion_negocio_flow.dart';
import 'package:provider/provider.dart';

class _ProviderControlable extends ConfiguracionNegocioProvider {
  _ProviderControlable({
    required FakeFirebaseFirestore firestore,
    this.freno,
    this.fallar = false,
  }) : super(
          rubro: 'Bodega',
          repository: NegocioRepository(firestore: firestore),
        );

  final Completer<void>? freno;
  final bool fallar;
  int llamadasGuardar = 0;

  @override
  Future<bool> guardar(String uid) async {
    llamadasGuardar++;
    final f = freno;
    if (f != null) await f.future;
    if (fallar) return false;
    return super.guardar(uid);
  }
}

void main() {
  void completarPaso0(ConfiguracionNegocioProvider p) {
    p.nombreNegocio = 'Bodega Ana';
    p.telefono = '999999999';
    p.direccion = 'Av. Lima 123';
    p.referencia = 'Frente al parque';
  }

  Future<void> montarFlujo(
    WidgetTester tester, {
    required ConfiguracionNegocioProvider provider,
    String? negocioId,
    VoidCallback? onVolver,
    VoidCallback? onCompletado,
    Future<void> Function(String uid, String? negocioId)? onRecargarProgreso,
  }) async {
    tester.view.physicalSize = const Size(500, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
            value: provider,
            child: ConfiguracionNegocioFlow(
              uid: 'usuario-1',
              negocioId: negocioId,
              onVolver: onVolver ?? () {},
              onCompletado: onCompletado ?? () {},
              onRecargarProgreso: onRecargarProgreso,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder popScopeDelFlujo() => find.descendant(
        of: find.byType(ConfiguracionNegocioFlow),
        matching: find.byType(PopScope),
      );

  Finder absorbDelFlujo() => find.descendant(
        of: find.byType(ConfiguracionNegocioFlow),
        matching: find.byType(AbsorbPointer),
      );

  testWidgets('el flujo se monta sin Scaffold ni SafeArea propios', (
    tester,
  ) async {
    await montarFlujo(
      tester,
      provider: _ProviderControlable(firestore: FakeFirebaseFirestore()),
    );

    expect(find.byType(Scaffold), findsNothing);
    expect(find.byType(SafeArea), findsNothing);
    expect(find.byType(ConfiguracionNegocioContent), findsOneWidget);
  });

  testWidgets('guardado exitoso llama una sola vez a onCompletado', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'negocioId': 'negocio-1',
    });
    final provider = _ProviderControlable(firestore: firestore);
    completarPaso0(provider);

    var completados = 0;
    var recargas = 0;
    String? uidRecargado;
    String? negocioIdRecargado;
    await montarFlujo(
      tester,
      provider: provider,
      negocioId: 'negocio-1',
      onCompletado: () => completados++,
      onRecargarProgreso: (uid, negocioId) async {
        recargas++;
        uidRecargado = uid;
        negocioIdRecargado = negocioId;
      },
    );

    provider.irAPaso(3);
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(provider.llamadasGuardar, 1);
    expect(recargas, 1);
    expect(uidRecargado, 'usuario-1');
    expect(negocioIdRecargado, 'negocio-1');
    expect(completados, 1);
  });

  testWidgets('doble clic en Finalizar no duplica el guardado', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'negocioId': 'negocio-1',
    });
    final freno = Completer<void>();
    final provider = _ProviderControlable(firestore: firestore, freno: freno);
    completarPaso0(provider);

    var completados = 0;
    await montarFlujo(
      tester,
      provider: provider,
      negocioId: 'negocio-1',
      onCompletado: () => completados++,
      onRecargarProgreso: (uid, negocioId) async {},
    );

    provider.irAPaso(3);
    await tester.pump();

    await tester.tap(find.text('Finalizar'));
    await tester.pump();
    await tester.tap(find.text('Finalizar'), warnIfMissed: false);
    await tester.pump();

    expect(provider.llamadasGuardar, 1);

    freno.complete();
    await tester.pumpAndSettle();

    expect(provider.llamadasGuardar, 1);
    expect(completados, 1);
  });

  testWidgets('un error de guardado mantiene al usuario en Configuración', (
    tester,
  ) async {
    final provider = _ProviderControlable(
      firestore: FakeFirebaseFirestore(),
      fallar: true,
    );
    completarPaso0(provider);

    var completados = 0;
    var recargas = 0;
    await montarFlujo(
      tester,
      provider: provider,
      negocioId: 'negocio-1',
      onCompletado: () => completados++,
      onRecargarProgreso: (uid, negocioId) async {
        recargas++;
      },
    );

    provider.irAPaso(3);
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(provider.llamadasGuardar, 1);
    expect(recargas, 0);
    expect(completados, 0);
    expect(find.byType(ConfiguracionNegocioContent), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
    expect(tester.widget<PopScope>(popScopeDelFlujo()).canPop, isTrue);
  });

  testWidgets('un error de recarga tampoco completa', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'negocioId': 'negocio-1',
    });
    final provider = _ProviderControlable(firestore: firestore);
    completarPaso0(provider);

    var completados = 0;
    var recargas = 0;
    await montarFlujo(
      tester,
      provider: provider,
      negocioId: 'negocio-1',
      onCompletado: () => completados++,
      onRecargarProgreso: (uid, negocioId) async {
        recargas++;
        throw StateError('sin red');
      },
    );

    provider.irAPaso(3);
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(provider.llamadasGuardar, 1);
    expect(recargas, 1);
    expect(completados, 0);
    expect(find.byType(ConfiguracionNegocioContent), findsOneWidget);
  });

  testWidgets('volver ejecuta onVolver', (tester) async {
    final provider = _ProviderControlable(firestore: FakeFirebaseFirestore());
    completarPaso0(provider);

    var volveres = 0;
    await montarFlujo(
      tester,
      provider: provider,
      onVolver: () => volveres++,
    );

    await tester.tap(find.text('Cambiar rubro'));
    await tester.pump();

    expect(volveres, 1);
  });

  testWidgets('navegación atrás bloqueada durante el guardado', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('usuario-1').set({
      'email': 'ana@example.com',
      'negocioId': 'negocio-1',
    });
    final freno = Completer<void>();
    final provider = _ProviderControlable(firestore: firestore, freno: freno);
    completarPaso0(provider);

    var volveres = 0;
    await montarFlujo(
      tester,
      provider: provider,
      negocioId: 'negocio-1',
      onVolver: () => volveres++,
      onRecargarProgreso: (uid, negocioId) async {},
    );

    provider.irAPaso(3);
    await tester.pump();

    await tester.tap(find.text('Finalizar'));
    await tester.pump();

    expect(tester.widget<PopScope>(popScopeDelFlujo()).canPop, isFalse);
    expect(tester.widget<AbsorbPointer>(absorbDelFlujo()).absorbing, isTrue);

    await tester.tap(find.byTooltip('Cambiar rubro'), warnIfMissed: false);
    await tester.pump();
    expect(volveres, 0);

    freno.complete();
    await tester.pumpAndSettle();

    expect(tester.widget<PopScope>(popScopeDelFlujo()).canPop, isTrue);
    expect(volveres, 0);
    expect(find.byType(ConfiguracionNegocioContent), findsOneWidget);
  });
}