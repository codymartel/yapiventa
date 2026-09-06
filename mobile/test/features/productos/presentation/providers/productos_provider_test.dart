import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/data/productos_repository.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductosProvider provider;

  Producto producto({String nombre = 'Cafe'}) =>
      Producto(negocioId: 'usuario-1', nombre: nombre, precio: 12.5);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    provider = ProductosProvider(
      uid: 'usuario-1',
      repository: ProductosRepository(firestore),
    );
  });

  tearDown(() => provider.dispose());

  Future<void> crearProductos(int cantidad) async {
    final coleccion = firestore
        .collection('users')
        .doc('usuario-1')
        .collection('productos');
    for (var i = 1; i <= cantidad; i++) {
      await coleccion.doc('producto-$i').set({
        ...producto(nombre: 'Producto $i').toMap(),
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 1, i)),
      });
    }
  }

  test('carga paginas de diez y evita duplicados', () async {
    await crearProductos(21);

    await provider.cargarProductos();
    expect(provider.productosFiltrados, hasLength(10));
    expect(provider.productosFiltrados.first.nombre, 'Producto 21');
    expect(provider.hayMas, isTrue);

    await provider.cargarMasProductos();
    expect(provider.productosFiltrados, hasLength(20));
    expect(provider.productosFiltrados[10].nombre, 'Producto 11');
    expect(provider.hayMas, isTrue);

    await provider.cargarMasProductos();
    expect(provider.productosFiltrados, hasLength(21));
    expect(provider.productosFiltrados.last.nombre, 'Producto 1');
    expect(provider.hayMas, isFalse);
    expect(
      provider.productosFiltrados.map((producto) => producto.id).toSet(),
      hasLength(21),
    );

    await provider.cargarMasProductos();
    expect(provider.productosFiltrados, hasLength(21));
  });

  test(
    'mantiene diez productos visibles al crear un producto nuevo',
    () async {
      await crearProductos(10);
      await provider.cargarProductos();

      final guardado = await provider.guardarProducto(
        producto(nombre: 'Producto nuevo'),
      );

      expect(guardado, isTrue);
      expect(provider.productosFiltrados, hasLength(10));
      expect(provider.productosFiltrados.first.nombre, 'Producto nuevo');
      expect(provider.productosFiltrados.first.id, isNotEmpty);
      expect(provider.hayMas, isTrue);
      expect(
        provider.totalProductos,
        11,
      );
    },
  );

  test('oculta ver mas al consultar despues de una pagina exacta', () async {
    await crearProductos(10);
    await provider.cargarProductos();

    expect(provider.productosFiltrados, hasLength(10));
    expect(provider.hayMas, isFalse);
    expect(provider.cargandoMas, isFalse);
  });
}
