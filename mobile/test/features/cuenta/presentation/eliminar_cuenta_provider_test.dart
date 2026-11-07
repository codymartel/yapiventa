import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/cuenta/application/eliminar_cuenta.dart';
import 'package:mobile/features/cuenta/data/cuenta_auth.dart';
import 'package:mobile/features/cuenta/data/eliminar_cuenta_repository.dart';
import 'package:mobile/features/cuenta/presentation/providers/eliminar_cuenta_provider.dart';
import 'package:mobile/features/cuenta/presentation/widgets/eliminar_cuenta_dialogo.dart';
import 'package:provider/provider.dart';

class _AuthFalso implements CuentaAuth {
  @override
  bool usaClave;
  Object? errorAlReautenticar;
  bool googleElegido = true;
  int reautenticaciones = 0;
  bool usuarioBorrado = false;
  bool googleOlvidado = false;

  _AuthFalso({this.usaClave = true});

  @override
  Future<void> reautenticarConClave(String clave) async {
    reautenticaciones++;
    if (errorAlReautenticar != null) throw errorAlReautenticar!;
  }

  @override
  Future<bool> reautenticarConGoogle() async {
    reautenticaciones++;
    return googleElegido;
  }

  @override
  Future<void> borrarUsuario() async => usuarioBorrado = true;

  @override
  Future<void> olvidarGoogle() async => googleOlvidado = true;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _AuthFalso auth;

  EliminarCuentaProvider crear({bool fallaBorrado = false}) {
    return EliminarCuentaProvider(
      eliminarCuenta: EliminarCuenta(
        datos: EliminarCuentaRepository(firestore: firestore),
        borrarUsuarioDeAcceso: () async {
          if (fallaBorrado) throw StateError('sin red');
          await auth.borrarUsuario();
        },
      ),
      auth: auth,
      uid: 'u1',
      negocioId: 'n1',
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = _AuthFalso();
    await firestore.doc('users/u1').set({'email': 'a@b.c'});
    await firestore.doc('negocios/n1').set({'propietarioUid': 'u1'});
  });

  test('contraseña vacía: avisa y no borra nada', () async {
    final provider = crear();

    expect(await provider.eliminar(), isFalse);

    expect(provider.error, contains('contraseña'));
    expect(auth.reautenticaciones, 0);
    expect((await firestore.doc('negocios/n1').get()).exists, isTrue);
  });

  test('contraseña incorrecta: mensaje claro y no borra nada', () async {
    auth.errorAlReautenticar = FirebaseAuthException(code: 'wrong-password');
    final provider = crear();

    expect(await provider.eliminar(clave: 'mala'), isFalse);

    expect(provider.error, 'La contraseña no es correcta.');
    expect((await firestore.doc('negocios/n1').get()).exists, isTrue);
    expect(auth.usuarioBorrado, isFalse);
  });

  test('contraseña correcta: borra todo, el acceso y suelta Google', () async {
    final provider = crear();

    expect(await provider.eliminar(clave: 'buena'), isTrue);

    expect(provider.error, isNull);
    expect((await firestore.doc('negocios/n1').get()).exists, isFalse);
    expect((await firestore.doc('users/u1').get()).exists, isFalse);
    expect(auth.usuarioBorrado, isTrue);
    expect(auth.googleOlvidado, isTrue);
  });

  test(
    'cuenta de Google: cerrar el selector no es error ni borra nada',
    () async {
      auth = _AuthFalso(usaClave: false)..googleElegido = false;
      final provider = crear();

      expect(await provider.eliminar(), isFalse);

      expect(provider.error, isNull);
      expect((await firestore.doc('negocios/n1').get()).exists, isTrue);
    },
  );

  test('cuenta de Google: elegir la cuenta borra todo', () async {
    auth = _AuthFalso(usaClave: false);
    final provider = crear();

    expect(await provider.eliminar(), isTrue);

    expect((await firestore.doc('negocios/n1').get()).exists, isFalse);
  });

  test('si falla el último paso avisa y se puede reintentar', () async {
    final provider = crear(fallaBorrado: true);

    expect(await provider.eliminar(clave: 'buena'), isFalse);

    expect(provider.error, contains('vuelve a intentarlo'));
    expect(provider.trabajando, isFalse);
    expect(auth.usuarioBorrado, isFalse);
  });

  group('diálogo', () {
    Future<void> abrir(WidgetTester tester, EliminarCuentaProvider provider) {
      return tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<EliminarCuentaProvider>.value(
            value: provider,
            child: const Scaffold(body: EliminarCuentaDialogo()),
          ),
        ),
      );
    }

    testWidgets('el botón se activa solo al escribir ELIMINAR', (tester) async {
      await abrir(tester, crear());
      final boton = find.widgetWithText(FilledButton, 'Eliminar para siempre');

      expect(tester.widget<FilledButton>(boton).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'eliminar');
      await tester.pump();
      expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);

      await tester.enterText(find.byType(TextField).first, 'ELIMINA');
      await tester.pump();
      expect(tester.widget<FilledButton>(boton).onPressed, isNull);
    });

    testWidgets('con correo pide la contraseña; con Google lo explica', (
      tester,
    ) async {
      await abrir(tester, crear());
      expect(find.text('Tu contraseña'), findsOneWidget);

      auth = _AuthFalso(usaClave: false);
      await abrir(tester, crear());
      expect(find.text('Tu contraseña'), findsNothing);
      expect(find.textContaining('cuenta de Google'), findsOneWidget);
    });

    testWidgets('una contraseña mala muestra el error y no borra', (
      tester,
    ) async {
      auth.errorAlReautenticar = FirebaseAuthException(
        code: 'invalid-credential',
      );
      await abrir(tester, crear());

      await tester.enterText(find.byType(TextField).first, 'ELIMINAR');
      await tester.enterText(find.byType(TextField).last, 'mala');
      await tester.pump();
      await tester.tap(find.text('Eliminar para siempre'));
      await tester.pumpAndSettle();

      expect(find.text('La contraseña no es correcta.'), findsOneWidget);
      expect((await firestore.doc('negocios/n1').get()).exists, isTrue);
    });
  });
}
