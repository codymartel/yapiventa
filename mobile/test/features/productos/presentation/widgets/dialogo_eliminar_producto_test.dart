import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/presentation/widgets/dialogo_eliminar_producto.dart';

void main() {
  testWidgets('cancelar devuelve false y no confirma la eliminación', (
    tester,
  ) async {
    bool? confirmacion;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              confirmacion = await showDialog<bool>(
                context: context,
                builder: (_) => const DialogoEliminarProducto(),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(confirmacion, isFalse);
    expect(find.byType(DialogoEliminarProducto), findsNothing);
  });

  testWidgets('eliminar devuelve true y confirma la eliminación', (
    tester,
  ) async {
    bool? confirmacion;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              confirmacion = await showDialog<bool>(
                context: context,
                builder: (_) => const DialogoEliminarProducto(),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(confirmacion, isTrue);
    expect(find.byType(DialogoEliminarProducto), findsNothing);
  });
}
