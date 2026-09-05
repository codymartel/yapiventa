import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('muestra la pantalla de inicio de sesión', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('YapiVenta'), findsOneWidget);
    expect(find.text('Ingresar con mi cuenta'), findsOneWidget);
    expect(find.text('Crear cuenta nueva'), findsOneWidget);
  });
}
