import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario_producto.dart';

void main() {
  testWidgets('permite editar un producto con stock cero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FormularioProducto(
          producto: Producto(
            id: 'producto-1',
            negocioId: 'usuario-1',
            nombre: 'Cafe',
            precio: 12.5,
            stock: 0,
            categoria: 'Bebidas',
            unidadMedidaNombre: 'Unidad',
          ),
          categoriasDisponibles: const ['Bebidas'],
          unidadesDisponibles: const [
            UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
          ],
          onCancelar: () {},
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Guardar producto'),
    );
    expect(boton.onPressed, isNotNull);
  });
}
