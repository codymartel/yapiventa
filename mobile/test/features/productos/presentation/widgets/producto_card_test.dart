import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/widgets/producto_card.dart';

void main() {
  // El producto que devuelve el formulario al guardar: sin los campos viejos
  // precio y stock (valen 0). Antes la tarjeta mostraba S/ 0.00 y Stock: 0.
  final recienGuardado = Producto(
    id: 'p1',
    negocioId: 'n1',
    nombre: 'Jamonada',
    categoria: 'Abarrotes',
    modoVenta: ModoVenta.medida,
    medidaFamilia: FamiliaUnidad.peso,
    medidaUnidad: 'kg',
    cantidadReferenciaBase: 250,
    precioCentavos: 300,
    stockBase: 16650,
  );

  Future<void> montar(WidgetTester tester, {required bool cuadricula}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: cuadricula ? 420 : 200,
              child: ProductoCard(
                producto: recienGuardado,
                esCuadricula: cuadricula,
                onEditar: () {},
                onEliminar: () {},
                onToggleDisponible: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('lista: precio como lo escribió + por kg, y stock real', (
    tester,
  ) async {
    await montar(tester, cuadricula: false);

    expect(find.text('S/ 3.00 / ¼ kg · S/ 12.00 / kg'), findsOneWidget);
    expect(find.text('16.65 kg'), findsOneWidget);
    expect(find.textContaining('S/ 0.00'), findsNothing);
  });

  testWidgets('cuadrícula: precio y «Stock: 16.65 kg»', (tester) async {
    await montar(tester, cuadricula: true);

    expect(find.text('S/ 3.00 / ¼ kg · S/ 12.00 / kg'), findsOneWidget);
    expect(find.text('Stock: 16.65 kg'), findsOneWidget);
    expect(find.textContaining('Stock: 0'), findsNothing);
  });
}
