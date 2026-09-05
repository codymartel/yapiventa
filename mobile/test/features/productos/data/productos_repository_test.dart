import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/data/productos_repository.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductosRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ProductosRepository(firestore);
  });

  Producto producto({
    String id = '',
    String nombre = 'Cafe',
    bool disponible = true,
  }) => Producto(
    id: id,
    negocioId: 'usuario-1',
    nombre: nombre,
    precio: 12.5,
    stock: 8,
    disponible: disponible,
  );

  test('crea productos nuevos y registra la fecha de creacion', () async {
    await repository.guardarProducto('usuario-1', producto());

    final productos = await firestore
        .collection('users')
        .doc('usuario-1')
        .collection('productos')
        .get();

    expect(productos.docs, hasLength(1));
    expect(productos.docs.single.data(), containsPair('nombre', 'Cafe'));
    expect(productos.docs.single.data()['fechaCreacion'], isA<Timestamp>());
  });

  test(
    'lee productos por fecha descendente e ignora documentos invalidos',
    () async {
      final coleccion = firestore
          .collection('users')
          .doc('usuario-1')
          .collection('productos');
      await coleccion.doc('antiguo').set({
        ...producto(nombre: 'Antiguo').toMap(),
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await coleccion.doc('reciente').set({
        ...producto(nombre: 'Reciente').toMap(),
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 2, 1)),
      });
      await coleccion.doc('invalido').set({
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 3, 1)),
      });

      final productos = await repository.obtenerProductos('usuario-1');

      expect(productos.map((producto) => producto.nombre), [
        'Reciente',
        'Antiguo',
      ]);
    },
  );

  test('actualiza disponibilidad y elimina un producto existente', () async {
    await firestore
        .collection('users')
        .doc('usuario-1')
        .collection('productos')
        .doc('producto-1')
        .set({
          ...producto(id: 'producto-1').toMap(),
          'fechaCreacion': Timestamp.now(),
        });

    await repository.guardarProducto(
      'usuario-1',
      producto(id: 'producto-1', nombre: 'Te'),
    );
    await repository.toggleDisponible('usuario-1', 'producto-1', false);

    final actualizado = await firestore
        .collection('users')
        .doc('usuario-1')
        .collection('productos')
        .doc('producto-1')
        .get();
    expect(actualizado.data(), containsPair('nombre', 'Te'));
    expect(actualizado.data(), containsPair('disponible', false));

    await repository.eliminarProducto('usuario-1', 'producto-1');

    expect(actualizado.exists, isTrue);
    expect(
      (await firestore
              .collection('users')
              .doc('usuario-1')
              .collection('productos')
              .doc('producto-1')
              .get())
          .exists,
      isFalse,
    );
  });
}
