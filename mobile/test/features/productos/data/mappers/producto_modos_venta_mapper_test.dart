import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

void main() {
  group('modo presentación: el mapper deriva la vista legacy', () {
    test('nombre de presentación, etiqueta de formato y precio por unidad', () {
      final datos = ProductoFirestoreMapper.paraFirestore(
        Producto(
          negocioId: 'negocio-1',
          nombre: 'Cerveza',
          modoVenta: ModoVenta.presentacion,
          presentacionId: 'botella',
          formatoValorBase: 625,
          formatoFamilia: FamiliaUnidad.volumen,
          formatoUnidad: 'ml',
          precioCentavos: 800,
          stock: 12,
        ),
      );

      expect(datos['modoVenta'], 'presentacion');
      expect(datos['presentacionId'], 'botella');
      expect(datos['unidadMedidaNombre'], 'Botella');
      expect(datos['fraccionesSeleccionadas'], ['625 ml']);
      expect(datos['precio'], 8.0);
      expect(datos['stock'], 12);
      expect(datos['precioCentavos'], 800);
      expect(datos['stockBase'], isNull);
    });

    test('ida y vuelta conserva el modelo completo', () {
      final producto = Producto(
        id: 'producto-1',
        negocioId: 'negocio-1',
        nombre: 'Crema',
        modoVenta: ModoVenta.presentacion,
        presentacionId: 'frasco',
        formatoValorBase: 250,
        formatoFamilia: FamiliaUnidad.volumen,
        formatoUnidad: 'ml',
        precioCentavos: 1550,
        stock: 4,
        categoria: 'Rostro',
      );

      final leido = ProductoFirestoreMapper.desdeFirestore(
        'producto-1',
        ProductoFirestoreMapper.paraFirestore(producto),
      );

      expect(leido, isNotNull);
      expect(leido!.modoVenta, ModoVenta.presentacion);
      expect(leido.presentacionId, 'frasco');
      expect(leido.formatoValorBase, 250);
      expect(leido.formatoFamilia, FamiliaUnidad.volumen);
      expect(leido.formatoUnidad, 'ml');
      expect(leido.precioCentavos, 1550);
      expect(leido.stock, 4);
      expect(leido.precio, 15.5);
      expect(leido.unidadMedidaNombre, 'Frasco');
      expect(leido.fraccionesSeleccionadas, ['250 ml']);
    });
  });

  group('modo medida: el mapper deriva la vista legacy', () {
    test('stock en unidad base se pisa a unidades visuales', () {
      final datos = ProductoFirestoreMapper.paraFirestore(
        Producto(
          negocioId: 'negocio-1',
          nombre: 'Arroz',
          modoVenta: ModoVenta.medida,
          medidaFamilia: FamiliaUnidad.peso,
          medidaUnidad: 'kg',
          cantidadReferenciaBase: 1000, // S/ 10 por 1 kg
          precioCentavos: 1000,
          stockBase: 1500,
        ),
      );

      expect(datos['modoVenta'], 'medida');
      expect(datos['unidadMedidaNombre'], 'kg');
      expect(datos['precio'], 10.0); // precio por 1 kg
      expect(datos['stock'], 1); // 1500 g -> 1 kg (piso, no 1.5)
      expect(datos['fraccionesSeleccionadas'], isEmpty);
      expect(datos['stockBase'], 1500);
    });

    test('referencia que no es unidad visual: precio por litro con piso', () {
      final datos = ProductoFirestoreMapper.paraFirestore(
        Producto(
          negocioId: 'negocio-1',
          nombre: 'Aceite',
          modoVenta: ModoVenta.medida,
          medidaFamilia: FamiliaUnidad.volumen,
          medidaUnidad: 'L',
          cantidadReferenciaBase: 250, // S/ 3 por 250 ml
          precioCentavos: 300,
          stockBase: 1750,
        ),
      );

      // (300 x 1000) ~/ 250 = 1200 céntimos = S/ 12 por litro.
      expect(datos['precio'], 12.0);
      expect(datos['stock'], 1); // 1750 ml -> 1 L
      expect(datos['unidadMedidaNombre'], 'L');
    });

    test('la unidad base como unidad visual no transforma nada', () {
      final datos = ProductoFirestoreMapper.paraFirestore(
        Producto(
          negocioId: 'negocio-1',
          nombre: 'Queso',
          modoVenta: ModoVenta.medida,
          medidaFamilia: FamiliaUnidad.peso,
          medidaUnidad: 'g',
          cantidadReferenciaBase: 100, // S/ 2 por 100 g
          precioCentavos: 200,
          stockBase: 750,
        ),
      );

      // La vista legacy debe ser coherente consigo misma: precio por la
      // unidad visual (g) y stock en esa misma unidad.
      expect(datos['precio'], 0.02); // 2 céntimos por g
      expect(datos['stock'], 750); // 750 g
      expect(datos['unidadMedidaNombre'], 'g');
      expect(datos['stockBase'], 750);
    });

    test('stock infinito y stock nulo caen al campo legacy', () {
      final datos = ProductoFirestoreMapper.paraFirestore(
        Producto(
          negocioId: 'negocio-1',
          nombre: 'Hielo',
          modoVenta: ModoVenta.medida,
          medidaFamilia: FamiliaUnidad.peso,
          medidaUnidad: 'kg',
          cantidadReferenciaBase: 1000,
          precioCentavos: 500,
          stockBase: null,
          stock: 9,
          esStockInfinito: true,
        ),
      );

      expect(datos['stock'], 9);
      expect(datos['stockBase'], isNull);
      expect(datos['esStockInfinito'], isTrue);
    });

    test('ida y vuelta conserva familia, referencia y stock base', () {
      final producto = Producto(
        id: 'producto-2',
        negocioId: 'negocio-1',
        nombre: 'Arroz',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 1000,
        stockBase: 1500,
      );

      final leido = ProductoFirestoreMapper.desdeFirestore(
        'producto-2',
        ProductoFirestoreMapper.paraFirestore(producto),
      );

      expect(leido!.modoVenta, ModoVenta.medida);
      expect(leido.medidaFamilia, FamiliaUnidad.peso);
      expect(leido.medidaUnidad, 'kg');
      expect(leido.cantidadReferenciaBase, 1000);
      expect(leido.precioCentavos, 1000);
      expect(leido.stockBase, 1500);
      // La vista legacy se reconstruye derivada, nunca al revés.
      expect(leido.stock, 1);
      expect(leido.precio, 10.0);
      expect(leido.unidadMedidaNombre, 'kg');
    });
  });

  group('documentos legacy sin modoVenta', () {
    test('se abren como presentación/unidad y conservan sus valores', () {
      final producto = ProductoFirestoreMapper.desdeFirestore('viejo-1', {
        'negocioId': 'negocio-1',
        'nombre': 'Gaseosa',
        'precio': 3.5,
        'stock': 7,
        'unidadMedidaNombre': 'Unidad',
        'fraccionesSeleccionadas': const ['1/2'],
      });

      expect(producto, isNotNull);
      expect(producto!.modoVenta, ModoVenta.presentacion);
      expect(producto.presentacionId, 'unidad');
      expect(producto.formatoValorBase, 0); // nunca se inventa el tamaño
      expect(producto.formatoFamilia, isNull);
      expect(producto.precioCentavos, 350);
      expect(producto.stock, 7);
      expect(producto.precio, 3.5);
      expect(producto.unidadMedidaNombre, 'Unidad');
      expect(producto.fraccionesSeleccionadas, ['1/2']);
      expect(producto.etiquetaUnidad, '');

      // Reescribir no pierde nada de lo que la web lee.
      final datos = ProductoFirestoreMapper.paraFirestore(producto);
      expect(datos['unidadMedidaNombre'], 'Unidad');
      expect(datos['precio'], 3.5);
      expect(datos['stock'], 7);
      expect(datos['fraccionesSeleccionadas'], ['1/2']);
    });

    test('un nombre de unidad desconocido se conserva como etiqueta', () {
      final producto = ProductoFirestoreMapper.desdeFirestore('viejo-2', {
        'negocioId': 'negocio-1',
        'nombre': 'Arroz',
        'precio': 4.0,
        'stock': 5,
        'unidadMedidaNombre': 'kg',
      });

      expect(producto!.modoVenta, ModoVenta.presentacion);
      expect(producto.presentacionId, '');
      expect(producto.etiquetaUnidad, 'kg');

      final datos = ProductoFirestoreMapper.paraFirestore(producto);
      expect(datos['unidadMedidaNombre'], 'kg');
      expect(datos['precio'], 4.0);
      expect(datos['stock'], 5);
    });

    test('una presentación conocida se resuelve y sus fracciones sobreviven', () {
      final producto = ProductoFirestoreMapper.desdeFirestore('viejo-3', {
        'negocioId': 'negocio-1',
        'nombre': 'Cerveza',
        'precio': 8.0,
        'stock': 20,
        'unidadMedidaNombre': 'Botella',
        'fraccionesSeleccionadas': const ['625 ml'],
      });

      expect(producto!.presentacionId, 'botella');
      expect(producto.fraccionesSeleccionadas, ['625 ml']);

      final datos = ProductoFirestoreMapper.paraFirestore(producto);
      expect(datos['unidadMedidaNombre'], 'Botella');
      // Sin formato conocido no se inventa etiqueta: se conserva la lista.
      expect(datos['fraccionesSeleccionadas'], ['625 ml']);
    });
  });
}
