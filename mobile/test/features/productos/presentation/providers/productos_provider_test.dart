import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/subidor_de_imagenes.dart';
import 'package:mobile/features/productos/application/use_cases/crear_producto.dart';
import 'package:mobile/features/productos/data/productos_repository.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_productos.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductosProvider provider;
  late _RepositorioProductosCreacionFake repositorioCreacion;
  late _SubidorDeImagenesFake subidorDeImagenes;

  Producto producto({String nombre = 'Cafe'}) =>
      Producto(negocioId: 'usuario-1', nombre: nombre, precio: 12.5);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repositorioCreacion = _RepositorioProductosCreacionFake();
    subidorDeImagenes = _SubidorDeImagenesFake();
    provider = ProductosProvider(
      uid: 'usuario-1',
      repository: ProductosRepository(firestore),
      crearProducto: CrearProducto(
        repositorioProductos: repositorioCreacion,
        subidorDeImagenes: subidorDeImagenes,
      ),
      subidorDeImagenes: subidorDeImagenes,
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

  test('mantiene diez productos visibles al crear un producto nuevo', () async {
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
    expect(provider.totalProductos, 11);
  });

  test('oculta ver mas al consultar despues de una pagina exacta', () async {
    await crearProductos(10);
    await provider.cargarProductos();

    expect(provider.productosFiltrados, hasLength(10));
    expect(provider.hayMas, isFalse);
    expect(provider.cargandoMas, isFalse);
  });

  test('mantiene estado de creación y añade el producto una vez', () async {
    final pendiente = Completer<Producto>();
    repositorioCreacion.respuestaPendiente = pendiente;

    final guardado = provider.crearProducto(producto(nombre: 'Nuevo'));

    expect(provider.creandoProducto, isTrue);
    expect(provider.errorMessage, isNull);
    expect(repositorioCreacion.llamadas, 1);

    pendiente.complete(
      repositorioCreacion.ultimoProducto!.copyWith(id: 'producto-nuevo'),
    );
    expect(await guardado, isTrue);
    expect(provider.creandoProducto, isFalse);
    expect(provider.productosFiltrados, hasLength(1));
    expect(provider.productosFiltrados.single.id, 'producto-nuevo');
  });

  test('bloquea una segunda creación mientras la primera continúa', () async {
    final pendiente = Completer<Producto>();
    repositorioCreacion.respuestaPendiente = pendiente;

    final primera = provider.crearProducto(
      producto(nombre: 'Primero'),
      imagenBytes: Uint8List.fromList([1]),
      nombreArchivo: 'primero.jpg',
    );
    final segunda = await provider.crearProducto(
      producto(nombre: 'Segundo'),
      imagenBytes: Uint8List.fromList([2]),
      nombreArchivo: 'segundo.jpg',
    );

    expect(segunda, isFalse);
    expect(subidorDeImagenes.llamadas, 1);
    expect(repositorioCreacion.llamadas, 1);

    pendiente.complete(
      repositorioCreacion.ultimoProducto!.copyWith(id: 'producto-1'),
    );
    expect(await primera, isTrue);
    expect(provider.productosFiltrados, hasLength(1));
  });

  test('restaura el estado y limpia el error al reintentar', () async {
    repositorioCreacion.error = Exception('fallo inicial');

    expect(await provider.crearProducto(producto()), isFalse);
    expect(provider.creandoProducto, isFalse);
    expect(provider.errorMessage, contains('fallo inicial'));

    repositorioCreacion.error = null;
    final pendiente = Completer<Producto>();
    repositorioCreacion.respuestaPendiente = pendiente;
    final reintento = provider.crearProducto(producto(nombre: 'Reintento'));

    expect(provider.creandoProducto, isTrue);
    expect(provider.errorMessage, isNull);

    pendiente.complete(
      repositorioCreacion.ultimoProducto!.copyWith(id: 'producto-reintento'),
    );
    expect(await reintento, isTrue);
    expect(provider.creandoProducto, isFalse);
  });
}

class _RepositorioProductosCreacionFake implements RepositorioProductos {
  int llamadas = 0;
  Producto? ultimoProducto;
  Object? error;
  Completer<Producto>? respuestaPendiente;

  @override
  Future<Producto> crearProducto(String uid, Producto producto) {
    llamadas++;
    ultimoProducto = producto;
    if (error != null) return Future.error(error!);
    final pendiente = respuestaPendiente;
    if (pendiente != null) return pendiente.future;
    return Future.value(producto.copyWith(id: 'producto-creado-$llamadas'));
  }
}

class _SubidorDeImagenesFake implements SubidorDeImagenes {
  int llamadas = 0;

  @override
  Future<ResultadoSubida> subir({
    required List<int> bytes,
    required String carpeta,
    required String nombreArchivo,
  }) async {
    llamadas++;
    return const ResultadoSubida(
      url: 'https://imagenes.test/producto.jpg',
      identificador: 'producto-public-id',
    );
  }

  @override
  Future<void> borrar(String identificador) async {}
}
