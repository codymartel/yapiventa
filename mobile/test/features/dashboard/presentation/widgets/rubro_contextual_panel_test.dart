import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/dashboard/presentation/widgets/rubro_contextual_panel.dart';

void main() {
  Future<void> mostrarPanel(
    WidgetTester tester,
    String rubro, {
    double width = 300,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: RubroContextualPanel(rubro: rubro),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const contenido = <String, List<String>>{
    'Bodega': [
      'Organizar productos vendidos por unidad, peso, volumen o presentación, controlar su disponibilidad y prepararlos para el catálogo web.',
      'Unidad, docena, gramos, kilogramos, mililitros, litros, botellas, bolsas, cajas y paquetes.',
      'No reemplaza una caja registradora fiscal, no emite comprobantes electrónicos y no calcula automáticamente rutas o distancias de delivery.',
    ],
    'Restaurante': [
      'Organizar una carta de comidas y bebidas, manejar precios, porciones y productos disponibles para pedidos.',
      'Unidad, porción, media porción, ¼ de porción, ⅛ de porción, vaso, botella, jarra, plato y combo.',
      'No administra mesas, comandas de cocina, recetas, costos de ingredientes ni reservas del local.',
    ],
    'Ropa': [
      'Crear un catálogo visual de prendas y controlar productos vendidos por unidad.',
      'Unidad, par, conjunto y paquete.',
      'Esta fase todavía no administra existencias independientes por talla y color. Las variantes se implementarán en Productos.',
    ],
    'Accesorios y regalos': [
      'Organizar accesorios, regalos y artículos vendidos individualmente o en conjuntos.',
      'Unidad, par, juego, set, paquete, caja y bolsa.',
      'No administra fabricación personalizada, órdenes de producción ni stock por variantes en esta fase.',
    ],
    'Belleza y cuidado personal': [
      'Organizar productos de belleza vendidos por unidad, peso, volumen o presentación.',
      'Unidad, gramos, kilogramos, mililitros, litros, frascos, botellas, potes, tubos y sachets.',
      'No realiza diagnósticos, recetas médicas ni control sanitario de medicamentos.',
    ],
    'Otros': [
      'Crear un catálogo básico de productos que puedan venderse con las funciones generales disponibles.',
      'Unidad y presentaciones comerciales básicas.',
      'No garantiza procesos especializados para todos los tipos de negocio. Solo ofrece catálogo, disponibilidad y las funciones generales de YapiVenta.',
    ],
  };

  for (final entry in contenido.entries) {
    testWidgets('${entry.key} muestra exactamente su alcance real', (
      tester,
    ) async {
      await mostrarPanel(tester, entry.key);

      expect(find.text('Sirve para'), findsOneWidget);
      expect(find.text('Medidas sugeridas'), findsOneWidget);
      expect(find.text('No incluye'), findsOneWidget);
      for (final texto in entry.value) {
        expect(find.text(texto), findsOneWidget);
      }
      expect(
        find.text(
          'YapiVenta es un gestor de catálogo, productos y tienda web. No es un sistema contable, tributario, médico ni logístico.',
        ),
        findsOneWidget,
      );
    });
  }

  for (final legacy in ['Farmacia', 'Ferretería']) {
    testWidgets('$legacy usa la ayuda compatible de Otros', (tester) async {
      await mostrarPanel(tester, legacy);

      expect(find.text(contenido['Otros']!.first), findsOneWidget);
    });
  }

  for (final escala in [1.0, 1.3, 2.0]) {
    testWidgets('no desborda en 280 px con texto $escala', (tester) async {
      await mostrarPanel(
        tester,
        'Belleza y cuidado personal',
        width: 280,
        textScaler: TextScaler.linear(escala),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
