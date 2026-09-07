import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

void main() {
  test('convierte Timestamp a DateTime al leer Firestore', () {
    final fecha = DateTime(2026, 9, 7, 12, 30);

    final producto = ProductoFirestoreMapper.desdeFirestore('producto-1', {
      'negocioId': 'usuario-1',
      'nombre': 'Cafe',
      'fechaVencimiento': Timestamp.fromDate(fecha),
    });

    expect(producto, isNotNull);
    expect(producto!.fechaVencimiento, fecha);
  });

  test('convierte DateTime a Timestamp conservando campos y formato', () {
    final fecha = DateTime(2026, 9, 7, 12, 30);
    final producto = Producto(
      id: 'producto-1',
      negocioId: 'usuario-1',
      nombre: 'Cafe',
      precio: 12.5,
      stock: 3,
      esStockInfinito: false,
      descripcion: 'Molido',
      categoria: 'Bebidas',
      disponible: true,
      tieneDelivery: true,
      urlImagen: 'https://imagenes.test/cafe.jpg',
      cloudinaryPublicId: 'productos/cafe',
      unidadMedidaNombre: 'Unidad',
      fraccionesSeleccionadas: const ['1/2'],
      fechaVencimiento: fecha,
    );

    final datos = ProductoFirestoreMapper.paraFirestore(producto);

    expect(datos.keys, {
      'negocioId',
      'nombre',
      'precio',
      'stock',
      'esStockInfinito',
      'descripcion',
      'categoria',
      'disponible',
      'tieneDelivery',
      'urlImagen',
      'cloudinaryPublicId',
      'unidadMedidaNombre',
      'fraccionesSeleccionadas',
      'fechaVencimiento',
    });
    expect(datos['fechaVencimiento'], isA<Timestamp>());
    expect((datos['fechaVencimiento'] as Timestamp).toDate(), fecha);
    expect(datos['nombre'], 'Cafe');
    expect(datos['disponible'], isTrue);
  });

  test('mantiene fecha nula y descarta documentos incompletos', () {
    final datos = ProductoFirestoreMapper.paraFirestore(
      Producto(negocioId: 'usuario-1', nombre: 'Cafe'),
    );

    expect(datos['fechaVencimiento'], isNull);
    expect(
      ProductoFirestoreMapper.desdeFirestore('incompleto', {'nombre': 'Cafe'}),
      isNull,
    );
  });
}
