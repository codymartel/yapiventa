import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario/foto_modelo.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario/foto_producto.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario_producto.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class ProductosProviderMock extends Mock implements ProductosProvider {}

class ProductoFake extends Fake implements Producto {}

OpcionPresentacion presentacion(
  String id, {
  List<FormatoPresentacion>? formatos,
  bool activa = true,
}) {
  return OpcionPresentacion(
    id: id,
    nombre: id == 'unidad' ? 'Unidad' : 'Botella',
    formatos:
        formatos ??
        [
          FormatoPresentacion(
            valorBase: 1,
            familia: FamiliaUnidad.conteo,
            unidadVisible: RegistroUnidades.unidad,
          ),
        ],
    activa: activa,
  );
}

CatalogoVentaPersistido catalogoConPresentaciones() => CatalogoVentaPersistido(
  presentaciones: [
    presentacion('unidad'),
    presentacion(
      'botella',
      formatos: [
        FormatoPresentacion(
          valorBase: 625,
          familia: FamiliaUnidad.volumen,
          unidadVisible: RegistroUnidades.ml,
        ),
        FormatoPresentacion(
          valorBase: 1000,
          familia: FamiliaUnidad.volumen,
          unidadVisible: RegistroUnidades.L,
        ),
      ],
    ),
  ],
  medidas: const [],
);

CatalogoVentaPersistido catalogoConMedida() => CatalogoVentaPersistido(
  presentaciones: [presentacion('unidad')],
  medidas: [
    MedidaVentaPersistida(
      id: 'peso',
      nombre: 'Peso',
      familia: FamiliaUnidad.peso,
      unidadBase: RegistroUnidades.g,
      unidadVisual: RegistroUnidades.kg,
      minimoBase: 100,
      incrementoBase: 50,
      permiteCantidad: true,
      permiteMonto: false,
      activa: true,
    ),
  ],
);

Widget formulario({
  Producto? producto,
  CatalogoVentaPersistido? catalogoVenta,
  bool sinCatalogo = false,
  bool cargandoVenta = false,
  String? ventaErrorMessage,
  Future<void> Function()? onReintentarVenta,
  ProductosProvider? provider,
  List<String> categorias = const ['Bebidas'],
  String rubro = '',
}) {
  final contenido = Scaffold(
    body: FormularioProducto(
      producto: producto,
      categoriasDisponibles: categorias,
      catalogoVenta: sinCatalogo
          ? null
          : (catalogoVenta ?? catalogoConPresentaciones()),
      cargandoVenta: cargandoVenta,
      ventaErrorMessage: ventaErrorMessage,
      onReintentarVenta: onReintentarVenta,
      rubro: rubro,
      onCancelar: () {},
    ),
  );
  return MaterialApp(
    home: provider == null
        ? contenido
        : ChangeNotifierProvider<ProductosProvider>.value(
            value: provider,
            child: contenido,
          ),
  );
}

/// Monta el formulario con un viewport grande: el diálogo es scrollable y
/// en 800x600 los campos quedan fuera del área visible.
Future<void> montar(WidgetTester tester, Widget widget) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 2600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Finder campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

Future<void> elegirEnDropdown(
  WidgetTester tester,
  String etiqueta,
  String opcion,
) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField &&
          widget.decoration.labelText == etiqueta,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
}

Producto capturarProductoGuardado(ProductosProviderMock provider) {
  return verify(
        () => provider.guardarProducto(
          captureAny(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
          fotosModelos: any(named: 'fotosModelos'),
        ),
      ).captured.single
      as Producto;
}

Producto capturarProductoCreado(ProductosProviderMock provider) {
  return verify(
        () => provider.crearProducto(
          captureAny(),
          imagenBytes: any(named: 'imagenBytes'),
          nombreArchivo: any(named: 'nombreArchivo'),
          fotosModelos: any(named: 'fotosModelos'),
        ),
      ).captured.single
      as Producto;
}

/// Un PNG de 1 × 1 píxel: una imagen válida que se puede dibujar.
final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Cambia el selector de galería del sistema por uno que siempre entrega una
/// foto. Se deshace solo al terminar la prueba.
void usarSelectorDeFotosFalso() {
  elegirFotoParaPruebas = () async =>
      XFile.fromData(_png1x1, name: 'foto.png', mimeType: 'image/png');
  addTearDown(() => elegirFotoParaPruebas = null);
}

/// Toca la foto de cada modelo que haya en pantalla (la foto es obligatoria).
Future<void> ponerFotos(WidgetTester tester) async {
  final cuantas = find.byType(FotoModelo).evaluate().length;
  for (var i = 0; i < cuantas; i++) {
    await tester.tap(find.byType(FotoModelo).at(i));
    await tester.pumpAndSettle();
  }
}
