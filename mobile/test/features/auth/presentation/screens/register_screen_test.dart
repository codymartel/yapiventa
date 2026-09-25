import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/google_sign_in_service.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class _GoogleSignInServiceMock extends Mock implements GoogleSignInService {}

class _AuthProviderMock extends Mock implements AuthProvider {}

void main() {
  late _GoogleSignInServiceMock googleSignInService;
  late _AuthProviderMock authProvider;
  late List<SingleChildWidget> providers;

  setUp(() {
    googleSignInService = _GoogleSignInServiceMock();
    authProvider = _AuthProviderMock();
    when(() => authProvider.isLoading).thenReturn(false);
    when(() => authProvider.errorMessage).thenReturn(null);
    when(() => authProvider.status).thenReturn(AuthStatus.idle);
    when(() => authProvider.limpiarError()).thenReturn(null);
    when(
      () => authProvider.autenticarConGoogle(
        any(),
        any(),
        esModoRegistro: any(named: 'esModoRegistro'),
      ),
    ).thenAnswer((_) async {});
    providers = [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ];
  });

  Finder botonGoogle() => find.text('Continuar con Google');

  ElevatedButton googleButton(WidgetTester tester) => tester
      .widget<ElevatedButton>(
        find.ancestor(
          of: botonGoogle(),
          matching: find.byType(ElevatedButton),
        ),
      );

  Finder scrollTerminos() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(Scrollable),
  );

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          home: RegisterScreen(googleSignInService: googleSignInService),
        ),
      ),
    );
    // El diálogo de términos sale solo en el primer frame. Mientras no se
    // acepte, su LinearProgressIndicator es indeterminado y el árbol nunca
    // converge: por eso aquí solo hay `pump`, nunca `pumpAndSettle`.
    await tester.pump();
  }

  /// Desplaza el diálogo hasta el final, que es lo que habilita el botón de
  /// aceptación.
  Future<void> aceptarTerminos(WidgetTester tester) async {
    await tester.drag(scrollTerminos(), const Offset(0, -4000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTENDIDO Y ACEPTO'));
    await tester.pumpAndSettle();
  }

  testWidgets('sin aceptar los términos, Google no puede registrar', (
    tester,
  ) async {
    await montar(tester);

    expect(googleButton(tester).onPressed, isNull);
    expect(find.text('🔒 Acepta los términos para continuar'), findsOneWidget);
    expect(find.text('🔒 Recomendado · más seguro y rápido'), findsNothing);
  });

  testWidgets('un toque con los términos sin aceptar no abre Google', (
    tester,
  ) async {
    await montar(tester);

    await tester.tap(botonGoogle(), warnIfMissed: false);
    await tester.pump();

    verifyNever(() => googleSignInService.iniciarSesionConGoogle());
    verifyNever(
      () => authProvider.autenticarConGoogle(
        any(),
        any(),
        esModoRegistro: any(named: 'esModoRegistro'),
      ),
    );
    expect(googleButton(tester).onPressed, isNull);
  });

  testWidgets('aceptados los términos, Google registra con esModoRegistro true', (
    tester,
  ) async {
    when(
      () => googleSignInService.iniciarSesionConGoogle(),
    ).thenAnswer(
      (_) async => GoogleTokens(idToken: 'id', accessToken: 'access'),
    );

    await montar(tester);
    await aceptarTerminos(tester);

    expect(googleButton(tester).onPressed, isNotNull);
    expect(find.text('🔒 Recomendado · más seguro y rápido'), findsOneWidget);

    await tester.tap(botonGoogle());
    await tester.pumpAndSettle();

    verify(() => googleSignInService.iniciarSesionConGoogle()).called(1);
    verify(
      () => authProvider.autenticarConGoogle(
        'id',
        'access',
        esModoRegistro: true,
      ),
    ).called(1);
  });

  testWidgets('cerrar los términos sin aceptar no registra con Google', (
    tester,
  ) async {
    await montar(tester);

    await tester.tap(find.text('Cerrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verifyNever(() => googleSignInService.iniciarSesionConGoogle());
    verifyNever(
      () => authProvider.autenticarConGoogle(
        any(),
        any(),
        esModoRegistro: any(named: 'esModoRegistro'),
      ),
    );
  });

  testWidgets('el gate de términos se mantiene con el correo también', (
    tester,
  ) async {
    await montar(tester);

    // Sin términos, tampoco el registro por correo puede avanzar.
    final botonCorreo = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'SIGUIENTE: Verificar Correo →'),
    );
    expect(botonCorreo.onPressed, isNull);
  });
}
