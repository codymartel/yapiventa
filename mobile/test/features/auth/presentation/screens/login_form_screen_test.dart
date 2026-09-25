import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/google_sign_in_service.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/auth/presentation/screens/login_form_screen.dart';
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
    providers = [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ];
  });

  Finder botonGoogle() => find.text('Continuar con Google');

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          home: LoginFormScreen(googleSignInService: googleSignInService),
        ),
      ),
    );
  }

  testWidgets('muestra el botón de Google en el login', (tester) async {
    await montar(tester);

    expect(botonGoogle(), findsOneWidget);
  });

  testWidgets('el login con Google pide tokens y usa esModoRegistro false', (
    tester,
  ) async {
    when(
      () => googleSignInService.iniciarSesionConGoogle(),
    ).thenAnswer(
      (_) async => GoogleTokens(idToken: 'id-token', accessToken: 'access'),
    );
    when(
      () => authProvider.autenticarConGoogle(
        any(),
        any(),
        esModoRegistro: any(named: 'esModoRegistro'),
      ),
    ).thenAnswer((_) async {});

    await montar(tester);
    await tester.tap(botonGoogle());
    await tester.pumpAndSettle();

    verify(
      () => authProvider.autenticarConGoogle(
        'id-token',
        'access',
        esModoRegistro: false,
      ),
    ).called(1);
  });

  testWidgets('cancelar el selector de Google no llama al provider', (
    tester,
  ) async {
    when(
      () => googleSignInService.iniciarSesionConGoogle(),
    ).thenAnswer((_) async => null);

    await montar(tester);
    await tester.tap(botonGoogle());
    await tester.pumpAndSettle();

    expect(botonGoogle(), findsOneWidget);
    verifyNever(
      () => authProvider.autenticarConGoogle(
        any(),
        any(),
        esModoRegistro: any(named: 'esModoRegistro'),
      ),
    );
  });

  testWidgets('el botón de Google se deshabilita mientras carga', (
    tester,
  ) async {
    when(() => authProvider.isLoading).thenReturn(true);

    await montar(tester);

    final boton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: botonGoogle(),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(boton.onPressed, isNull);
  });
}
