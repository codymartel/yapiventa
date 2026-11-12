import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/apariencia/domain/tamano_letra.dart';
import 'package:mobile/features/apariencia/presentation/providers/apariencia_provider.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/user_repository.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/main.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthRepositoryFake extends Mock implements AuthRepository {}

// El tamaño de letra de Configuración se aplica arriba de todo (MyApp), así
// vale en cualquier pantalla, también en el inicio de sesión.

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mostrar(WidgetTester tester, AparienciaProvider apariencia) {
    final auth = _AuthRepositoryFake();
    final firestore = FakeFirebaseFirestore();
    when(() => auth.cambiosDeAuth).thenAnswer((_) => Stream.value(null));
    when(() => auth.usuarioActual).thenReturn(null);
    return tester.pumpWidget(
      MyApp(
        authRepository: auth,
        userRepository: UserRepository(firestore: firestore),
        negocioRepository: NegocioRepository(firestore: firestore),
        apariencia: apariencia,
      ),
    );
  }

  double escalaEnPantalla(WidgetTester tester) =>
      MediaQuery.textScalerOf(
        tester.element(find.text('Ingresar con mi cuenta')),
      ).scale(10) /
      10;

  testWidgets('con «Normal» deja la letra del teléfono', (tester) async {
    final apariencia = AparienciaProvider();
    addTearDown(apariencia.dispose);
    await mostrar(tester, apariencia);
    await tester.pumpAndSettle();

    expect(escalaEnPantalla(tester), 1);
  });

  testWidgets('cambiar el tamaño agranda la letra al instante', (tester) async {
    final apariencia = AparienciaProvider(tamanoLetra: TamanoLetra.grande);
    addTearDown(apariencia.dispose);
    await mostrar(tester, apariencia);
    await tester.pumpAndSettle();
    expect(escalaEnPantalla(tester), closeTo(1.15, 1e-9));

    await apariencia.cambiarTamanoLetra(TamanoLetra.muyGrande);
    await tester.pumpAndSettle();
    expect(escalaEnPantalla(tester), closeTo(1.3, 1e-9));
    expect(tester.takeException(), isNull);
  });
}
