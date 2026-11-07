import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/application/services/calculo_hoja_producto.dart';
import 'package:mobile/features/caja/presentation/widgets/mostrar_hoja_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

/// Un polo con 2 colores, tallas con stock y 2 extras.
Producto poloDePrueba() => Producto(
  id: 'polo',
  negocioId: 'n1',
  nombre: 'Polo básico',
  stock: 8,
  precioCentavos: 3500,
  tituloModelos: 'Color',
  tituloFilas: 'Talla',
  modelos: const [
    ModeloProducto(
      id: 'azul',
      nombre: 'Azul',
      filas: [
        FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 3),
        FilaVenta(id: 'm', etiqueta: 'M', precioCentavos: 3500, stock: 5),
        FilaVenta(id: 'l', etiqueta: 'L', precioCentavos: 3500, stock: 0),
      ],
    ),
    ModeloProducto(
      id: 'rojo',
      nombre: 'Rojo',
      filas: [
        FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 2),
      ],
    ),
  ],
  extras: const [
    ExtraProducto(id: 'bord', nombre: 'Bordado', precioCentavos: 800),
    ExtraProducto(id: 'bolsa', nombre: 'Bolsa regalo', precioCentavos: 200),
  ],
);

/// Un plato con UN solo modelo y 3 tamaños (no hay color que elegir).
Producto polloDePrueba() => Producto(
  id: 'pollo',
  negocioId: 'n1',
  nombre: 'Pollo a la brasa',
  esStockInfinito: true,
  precioCentavos: 1800,
  tituloFilas: 'Tamaño',
  modelos: const [
    ModeloProducto(
      id: 'pollo',
      nombre: 'Pollo',
      filas: [
        FilaVenta(id: 'c', etiqueta: 'Un cuarto', precioCentavos: 1800),
        FilaVenta(id: 'm', etiqueta: 'Medio', precioCentavos: 3400),
        FilaVenta(id: 'e', etiqueta: 'Entero', precioCentavos: 6200),
      ],
    ),
  ],
  extras: const [
    ExtraProducto(id: 'aji', nombre: 'Ají extra', precioCentavos: 100),
  ],
);

/// Abre la hoja del producto dentro de una pantalla de prueba y recuerda qué
/// pasó (qué se eligió, con qué acción se cerró). Lo comparten las pruebas de
/// la hoja.
class BancoHoja {
  SeleccionProductoCaja? ultima;
  AccionHojaProducto? accionRecibida;
  AccionHojaProducto? cerrada;
  int cerrados = 0;
  String? errorDeAgregar;

  void reiniciar() {
    ultima = null;
    accionRecibida = null;
    cerrada = null;
    cerrados = 0;
    errorDeAgregar = null;
  }

  Future<void> abrir(
    WidgetTester tester,
    Producto producto, {
    double ancho = 390,
    double alto = 780,
  }) async {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  cerrada = await mostrarHojaProducto(
                    context,
                    producto: producto,
                    onConfirmar: (sel, accion) {
                      ultima = sel;
                      accionRecibida = accion;
                      return errorDeAgregar;
                    },
                  );
                  cerrados++;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// El botón (relleno o con borde) que contiene [texto].
  Finder boton(String texto) => find.ancestor(
    of: find.textContaining(texto),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  bool habilitado(WidgetTester t, String texto) =>
      t.widget<ButtonStyleButton>(boton(texto)).onPressed != null;
}
