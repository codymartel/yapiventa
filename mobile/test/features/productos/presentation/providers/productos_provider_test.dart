import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/subidor_de_imagenes.dart';
import 'package:mobile/features/productos/application/use_cases/cambiar_disponibilidad_producto.dart';
import 'package:mobile/features/productos/application/use_cases/crear_producto.dart';
import 'package:mobile/features/productos/application/use_cases/editar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/eliminar_producto.dart';
import 'package:mobile/features/productos/application/use_cases/obtener_pagina_productos.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/data/productos_repository.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_productos.dart';
import 'package:mobile/features/productos/presentation/providers/productos_provider.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductosProvider provider;
  late _RepositorioProductosCreacionFake repositorioCreacion;
  late _SubidorDeImagenesFake subidorDeImagenes;

  Producto producto({
    String id = '',
    String nombre = 'Cafe',
    String categoria = '',
    bool disponible = true,
  }) => Producto(
    id: id,
    negocioId: 'usuario-1',
    nombre: nombre,
    precio: 12.5,
    categoria: categoria,
    disponible: disponible,
  );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repositorioCreacion = _RepositorioProductosCreacionFake();
    subidorDeImagenes = _SubidorDeImagenesFake();
    final repository = ProductosRepository(firestore);
    provider = ProductosProvider(
      uid: 'usuario-1',
      cambiarDisponibilidadProducto: CambiarDisponibilidadProducto(repository),
      crearProducto: CrearProducto(
        repositorioProductos: repositorioCreacion,
        subidorDeImagenes: subidorDeImagenes,
      ),
      editarProducto: EditarProducto(repositorioCreacion, subidorDeImagenes),
      eliminarProducto: EliminarProducto(repositorioCreacion),
      obtenerPaginaProductos: ObtenerPaginaProductos(repository),
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
        ...ProductoFirestoreMapper.paraFirestore(
          producto(nombre: 'Producto $i'),
        ),
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 1, i)),
      });
    }
  }

  ProductosProvider crearProviderPaginado(
    _RepositorioProductosCreacionFake repository,
  ) {
    return ProductosProvider(
      uid: 'usuario-1',
      cambiarDisponibilidadProducto: CambiarDisponibilidadProducto(repository),
      crearProducto: CrearProducto(
        repositorioProductos: repository,
        subidorDeImagenes: subidorDeImagenes,
      ),
      editarProducto: EditarProducto(repository, subidorDeImagenes),
      eliminarProducto: EliminarProducto(repository),
      obtenerPaginaProductos: ObtenerPaginaProductos(repository),
    );
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

  test('filtra en memoria por nombre, categoría y disponibilidad', () async {
    final repository = _RepositorioProductosCreacionFake();
    repository.pagina = PaginaProductos(
      productos: [
        producto(
          id: 'producto-1',
          nombre: 'Café   molido',
          categoria: 'Bebidas calientes',
        ),
        producto(
          id: 'producto-2',
          nombre: 'Café instantáneo',
          categoria: 'Bebidas calientes',
          disponible: false,
        ),
        producto(
          id: 'producto-3',
          nombre: 'Pan integral',
          categoria: 'Panadería',
        ),
      ],
      ultimoCursor: const _CursorProductosPrueba('pagina-1'),
      hayMas: false,
    );
    final providerFiltrado = crearProviderPaginado(repository);
    addTearDown(providerFiltrado.dispose);
    await providerFiltrado.cargarProductos();

    final productosIniciales = providerFiltrado.productosFiltrados;
    expect(
      identical(productosIniciales, providerFiltrado.productosFiltrados),
      isTrue,
    );
    expect(
      providerFiltrado.filtroDisponibilidad,
      FiltroDisponibilidadProducto.todos,
    );

    providerFiltrado.actualizarCategoriaSeleccionada('  bebidas   CALIENTES ');
    providerFiltrado.actualizarFiltroDisponibilidad(
      FiltroDisponibilidadProducto.disponible,
    );
    expect(providerFiltrado.productosFiltrados.single.id, 'producto-1');

    providerFiltrado.actualizarBusqueda('  CAFÉ   instantáneo  ');
    providerFiltrado.actualizarFiltroDisponibilidad(
      FiltroDisponibilidadProducto.noDisponible,
    );

    expect(providerFiltrado.productosFiltrados.single.id, 'producto-2');
    expect(repository.llamadasPagina, 1);

    providerFiltrado.actualizarBusqueda('sin coincidencias');
    expect(providerFiltrado.productosFiltrados, isEmpty);
    expect(
      providerFiltrado.mensajeSinResultados,
      'No hay resultados entre los productos cargados.',
    );
    expect(repository.llamadasPagina, 1);
  });

  test('Ver más invalida la caché filtrada con la nueva página', () async {
    final repository = _RepositorioProductosCreacionFake();
    const primerCursor = _CursorProductosPrueba('pagina-1');
    repository.paginas.addAll([
      PaginaProductos(
        productos: [producto(id: 'producto-1', nombre: 'Café clásico')],
        ultimoCursor: primerCursor,
        hayMas: true,
      ),
      PaginaProductos(
        productos: [producto(id: 'producto-2', nombre: 'Café premium')],
        ultimoCursor: const _CursorProductosPrueba('pagina-2'),
        hayMas: false,
      ),
    ]);
    final providerFiltrado = crearProviderPaginado(repository);
    addTearDown(providerFiltrado.dispose);
    await providerFiltrado.cargarProductos();
    providerFiltrado.actualizarBusqueda(' café ');

    final primeraPaginaFiltrada = providerFiltrado.productosFiltrados;
    expect(primeraPaginaFiltrada, hasLength(1));
    expect(
      identical(primeraPaginaFiltrada, providerFiltrado.productosFiltrados),
      isTrue,
    );

    await providerFiltrado.cargarMasProductos();

    expect(providerFiltrado.productosFiltrados, hasLength(2));
    expect(repository.llamadasPagina, 2);
  });

  test('bloquea cargas iniciales concurrentes y usa cursor nulo', () async {
    final repository = _RepositorioProductosCreacionFake();
    final pendiente = Completer<PaginaProductos>();
    repository.paginaPendiente = pendiente;
    final providerPaginado = crearProviderPaginado(repository);
    addTearDown(providerPaginado.dispose);

    final primera = providerPaginado.cargarProductos();
    final segunda = providerPaginado.cargarProductos();

    expect(repository.llamadasPagina, 1);
    expect(repository.cursores.single, isNull);
    expect(repository.limites.single, 10);

    pendiente.complete(
      PaginaProductos(
        productos: [producto(nombre: 'Primero')],
        ultimoCursor: const _CursorProductosPrueba('pagina-1'),
        hayMas: false,
      ),
    );
    await Future.wait([primera, segunda]);

    expect(providerPaginado.cargando, isFalse);
    expect(providerPaginado.productosFiltrados, hasLength(1));
  });

  test('bloquea dos solicitudes de la siguiente página', () async {
    final repository = _RepositorioProductosCreacionFake();
    const primerCursor = _CursorProductosPrueba('pagina-1');
    repository.pagina = PaginaProductos(
      productos: [producto(id: 'producto-1', nombre: 'Primero')],
      ultimoCursor: primerCursor,
      hayMas: true,
    );
    final providerPaginado = crearProviderPaginado(repository);
    addTearDown(providerPaginado.dispose);
    await providerPaginado.cargarProductos();

    final pendiente = Completer<PaginaProductos>();
    repository.paginaPendiente = pendiente;
    final primera = providerPaginado.cargarMasProductos();
    final segunda = providerPaginado.cargarMasProductos();

    expect(repository.llamadasPagina, 2);
    expect(repository.cursores, [null, same(primerCursor)]);

    pendiente.complete(
      PaginaProductos(
        productos: [producto(id: 'producto-2', nombre: 'Segundo')],
        ultimoCursor: const _CursorProductosPrueba('pagina-2'),
        hayMas: false,
      ),
    );
    await Future.wait([primera, segunda]);

    expect(providerPaginado.cargandoMas, isFalse);
    expect(providerPaginado.productosFiltrados, hasLength(2));
    expect(providerPaginado.hayMas, isFalse);
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

  test('actualiza el producto local después de editarlo', () async {
    final repository = _RepositorioProductosCreacionFake();
    repository.pagina = PaginaProductos(
      productos: [producto(id: 'producto-1', nombre: 'Original')],
      ultimoCursor: const _CursorProductosPrueba('pagina-1'),
      hayMas: false,
    );
    final providerEdicion = crearProviderPaginado(repository);
    addTearDown(providerEdicion.dispose);
    await providerEdicion.cargarProductos();

    final exito = await providerEdicion.guardarProducto(
      producto(id: 'producto-1', nombre: 'Editado'),
    );

    expect(exito, isTrue);
    expect(repository.llamadasGuardado, 1);
    expect(providerEdicion.productosFiltrados, hasLength(1));
    expect(providerEdicion.productosFiltrados.single.nombre, 'Editado');
  });

  test('bloquea un segundo envío mientras edita', () async {
    final repository = _RepositorioProductosCreacionFake();
    final pendiente = Completer<String>();
    repository.guardadoPendiente = pendiente;
    final providerEdicion = crearProviderPaginado(repository);
    addTearDown(providerEdicion.dispose);

    final primera = providerEdicion.guardarProducto(
      producto(id: 'producto-1', nombre: 'Primero'),
    );
    final segunda = await providerEdicion.guardarProducto(
      producto(id: 'producto-1', nombre: 'Segundo'),
    );

    expect(providerEdicion.editandoProducto, isTrue);
    expect(segunda, isFalse);
    expect(repository.llamadasGuardado, 1);

    pendiente.complete('producto-1');
    expect(await primera, isTrue);
    expect(providerEdicion.editandoProducto, isFalse);
  });

  test('restaura el estado y conserva la lista si la edición falla', () async {
    final repository = _RepositorioProductosCreacionFake();
    repository.pagina = PaginaProductos(
      productos: [producto(id: 'producto-1', nombre: 'Original')],
      ultimoCursor: const _CursorProductosPrueba('pagina-1'),
      hayMas: false,
    );
    final providerEdicion = crearProviderPaginado(repository);
    addTearDown(providerEdicion.dispose);
    await providerEdicion.cargarProductos();
    repository.errorGuardado = Exception('Firestore no disponible');

    final exito = await providerEdicion.guardarProducto(
      producto(id: 'producto-1', nombre: 'Editado'),
    );

    expect(exito, isFalse);
    expect(providerEdicion.editandoProducto, isFalse);
    expect(providerEdicion.errorMessage, contains('Firestore no disponible'));
    expect(providerEdicion.productosFiltrados.single.nombre, 'Original');

    repository.errorGuardado = null;
    expect(
      await providerEdicion.guardarProducto(
        producto(id: 'producto-1', nombre: 'Reintento'),
      ),
      isTrue,
    );
    expect(providerEdicion.errorMessage, isNull);
    expect(providerEdicion.productosFiltrados.single.nombre, 'Reintento');
  });

  test('elimina el producto local sin recargar la página', () async {
    final repository = _RepositorioProductosCreacionFake();
    repository.pagina = PaginaProductos(
      productos: [
        producto(id: 'producto-1', nombre: 'Primero'),
        producto(id: 'producto-2', nombre: 'Segundo'),
      ],
      ultimoCursor: const _CursorProductosPrueba('pagina-1'),
      hayMas: false,
    );
    final providerEliminacion = crearProviderPaginado(repository);
    addTearDown(providerEliminacion.dispose);
    await providerEliminacion.cargarProductos();

    final exito = await providerEliminacion.eliminarProducto('producto-1');

    expect(exito, isTrue);
    expect(repository.llamadasEliminar, 1);
    expect(repository.llamadasPagina, 1);
    expect(providerEliminacion.productosFiltrados, hasLength(1));
    expect(providerEliminacion.productosFiltrados.single.id, 'producto-2');
  });

  test('muestra el error y conserva la lista si eliminar falla', () async {
    final repository = _RepositorioProductosCreacionFake();
    repository.pagina = PaginaProductos(
      productos: [producto(id: 'producto-1', nombre: 'Primero')],
      ultimoCursor: const _CursorProductosPrueba('pagina-1'),
      hayMas: false,
    );
    repository.errorEliminar = Exception('Firestore no disponible');
    final providerEliminacion = crearProviderPaginado(repository);
    addTearDown(providerEliminacion.dispose);
    await providerEliminacion.cargarProductos();

    final exito = await providerEliminacion.eliminarProducto('producto-1');

    expect(exito, isFalse);
    expect(repository.llamadasEliminar, 1);
    expect(repository.llamadasPagina, 1);
    expect(
      providerEliminacion.errorMessage,
      'No se pudo eliminar el producto.',
    );
    expect(providerEliminacion.productosFiltrados.single.id, 'producto-1');
  });

  test('actualiza la disponibilidad local sin recargar la lista', () async {
    final repository = _RepositorioProductosCreacionFake();
    repository.pagina = PaginaProductos(
      productos: [producto(id: 'producto-1')],
      ultimoCursor: const _CursorProductosPrueba('pagina-1'),
      hayMas: false,
    );
    final providerDisponibilidad = crearProviderPaginado(repository);
    addTearDown(providerDisponibilidad.dispose);
    await providerDisponibilidad.cargarProductos();

    final exito = await providerDisponibilidad.toggleDisponible(
      'producto-1',
      false,
    );

    expect(exito, isTrue);
    expect(repository.llamadasDisponibilidad, 1);
    expect(repository.ultimaDisponibilidad, isFalse);
    expect(repository.llamadasPagina, 1);
    expect(
      providerDisponibilidad.productosFiltrados.single.disponible,
      isFalse,
    );
  });

  test('conserva la disponibilidad local si la actualización falla', () async {
    final repository = _RepositorioProductosCreacionFake();
    repository.pagina = PaginaProductos(
      productos: [producto(id: 'producto-1')],
      ultimoCursor: const _CursorProductosPrueba('pagina-1'),
      hayMas: false,
    );
    repository.errorDisponibilidad = Exception('Firestore no disponible');
    final providerDisponibilidad = crearProviderPaginado(repository);
    addTearDown(providerDisponibilidad.dispose);
    await providerDisponibilidad.cargarProductos();

    final exito = await providerDisponibilidad.toggleDisponible(
      'producto-1',
      false,
    );

    expect(exito, isFalse);
    expect(repository.llamadasDisponibilidad, 1);
    expect(repository.llamadasPagina, 1);
    expect(
      providerDisponibilidad.errorMessage,
      'No se pudo actualizar el producto.',
    );
    expect(providerDisponibilidad.productosFiltrados.single.disponible, isTrue);
  });

  test('bloquea llamadas concurrentes para el mismo producto', () async {
    final repository = _RepositorioProductosCreacionFake();
    repository.pagina = PaginaProductos(
      productos: [producto(id: 'producto-1')],
      ultimoCursor: const _CursorProductosPrueba('pagina-1'),
      hayMas: false,
    );
    final pendiente = Completer<void>();
    repository.disponibilidadPendiente = pendiente;
    final providerDisponibilidad = crearProviderPaginado(repository);
    addTearDown(providerDisponibilidad.dispose);
    await providerDisponibilidad.cargarProductos();

    final primera = providerDisponibilidad.toggleDisponible(
      'producto-1',
      false,
    );
    final segunda = await providerDisponibilidad.toggleDisponible(
      'producto-1',
      false,
    );

    expect(segunda, isFalse);
    expect(
      providerDisponibilidad.cambiandoDisponibilidad('producto-1'),
      isTrue,
    );
    expect(repository.llamadasDisponibilidad, 1);
    expect(providerDisponibilidad.productosFiltrados.single.disponible, isTrue);

    pendiente.complete();
    expect(await primera, isTrue);
    expect(
      providerDisponibilidad.cambiandoDisponibilidad('producto-1'),
      isFalse,
    );
    expect(
      providerDisponibilidad.productosFiltrados.single.disponible,
      isFalse,
    );
  });
}

class _RepositorioProductosCreacionFake implements RepositorioProductos {
  int llamadas = 0;
  int llamadasGuardado = 0;
  int llamadasEliminar = 0;
  int llamadasDisponibilidad = 0;
  int llamadasPagina = 0;
  final List<CursorProductos?> cursores = [];
  final List<int> limites = [];
  Producto? ultimoProducto;
  Object? error;
  Object? errorGuardado;
  Object? errorEliminar;
  Object? errorDisponibilidad;
  Completer<Producto>? respuestaPendiente;
  Completer<String>? guardadoPendiente;
  Completer<void>? disponibilidadPendiente;
  bool? ultimaDisponibilidad;
  PaginaProductos pagina = const PaginaProductos(
    productos: [],
    ultimoCursor: null,
    hayMas: false,
  );
  final List<PaginaProductos> paginas = [];
  Completer<PaginaProductos>? paginaPendiente;

  @override
  Future<PaginaProductos> obtenerPaginaProductos(
    String uid, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) {
    llamadasPagina++;
    cursores.add(despuesDe);
    limites.add(limite);
    final pendiente = paginaPendiente;
    if (pendiente != null) return pendiente.future;
    if (paginas.isNotEmpty) return Future.value(paginas.removeAt(0));
    return Future.value(pagina);
  }

  @override
  Future<Producto> crearProducto(String uid, Producto producto) {
    llamadas++;
    ultimoProducto = producto;
    if (error != null) return Future.error(error!);
    final pendiente = respuestaPendiente;
    if (pendiente != null) return pendiente.future;
    return Future.value(producto.copyWith(id: 'producto-creado-$llamadas'));
  }

  @override
  Future<String> guardarProducto(String uid, Producto producto) {
    llamadasGuardado++;
    if (errorGuardado != null) return Future.error(errorGuardado!);
    return guardadoPendiente?.future ?? Future.value(producto.id);
  }

  @override
  Future<void> eliminarProducto(String uid, String productoId) async {
    llamadasEliminar++;
    if (errorEliminar != null) throw errorEliminar!;
  }

  @override
  Future<void> toggleDisponible(
    String uid,
    String productoId,
    bool disponible,
  ) {
    llamadasDisponibilidad++;
    ultimaDisponibilidad = disponible;
    if (errorDisponibilidad != null) {
      return Future.error(errorDisponibilidad!);
    }
    return disponibilidadPendiente?.future ?? Future.value();
  }
}

class _CursorProductosPrueba implements CursorProductos {
  final String valor;

  const _CursorProductosPrueba(this.valor);
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
