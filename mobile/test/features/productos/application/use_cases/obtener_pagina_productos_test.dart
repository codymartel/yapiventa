import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/use_cases/obtener_pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_productos.dart';

void main() {
  late _RepositorioProductosFake repository;
  late ObtenerPaginaProductos obtenerPaginaProductos;

  setUp(() {
    repository = _RepositorioProductosFake();
    obtenerPaginaProductos = ObtenerPaginaProductos(repository);
  });

  test(
    'obtiene la primera página con cursor nulo y el límite indicado',
    () async {
      final paginaEsperada = PaginaProductos(
        productos: [Producto(negocioId: 'usuario-1', nombre: 'Cafe')],
        ultimoCursor: const _CursorProductosPrueba('pagina-1'),
        hayMas: true,
      );
      repository.respuesta = paginaEsperada;

      final pagina = await obtenerPaginaProductos(
        negocioId: 'negocio-1',
        limite: 12,
      );

      expect(pagina, same(paginaEsperada));
      expect(repository.llamadas, 1);
      expect(repository.ultimoNegocioId, 'negocio-1');
      expect(repository.ultimoCursor, isNull);
      expect(repository.ultimoLimite, 12);
    },
  );

  test('envía el cursor recibido para obtener la página siguiente', () async {
    const cursor = _CursorProductosPrueba('pagina-1');

    await obtenerPaginaProductos(negocioId: 'negocio-1', despuesDe: cursor);

    expect(repository.ultimoCursor, same(cursor));
    expect(repository.ultimoLimite, 10);
  });

  test('propaga el error del repositorio', () async {
    final error = Exception('No se pudo consultar Firestore');
    repository.error = error;

    await expectLater(
      obtenerPaginaProductos(negocioId: 'negocio-1'),
      throwsA(same(error)),
    );
  });
}

class _RepositorioProductosFake implements RepositorioProductos {
  int llamadas = 0;
  String? ultimoNegocioId;
  CursorProductos? ultimoCursor;
  int? ultimoLimite;
  Object? error;
  PaginaProductos respuesta = const PaginaProductos(
    productos: [],
    ultimoCursor: null,
    hayMas: false,
  );

  @override
  Future<PaginaProductos> obtenerPaginaProductos(
    String negocioId, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) async {
    llamadas++;
    ultimoNegocioId = negocioId;
    ultimoCursor = despuesDe;
    ultimoLimite = limite;
    if (error != null) throw error!;
    return respuesta;
  }

  @override
  Future<Producto> crearProducto(String negocioId, Producto producto) {
    throw UnimplementedError();
  }

  @override
  Future<String> guardarProducto(String negocioId, Producto producto) {
    throw UnimplementedError();
  }

  @override
  Future<void> eliminarProducto(String negocioId, String productoId) {
    throw UnimplementedError();
  }

  @override
  Future<void> toggleDisponible(
    String negocioId,
    String productoId,
    bool disponible,
  ) {
    throw UnimplementedError();
  }
}

class _CursorProductosPrueba implements CursorProductos {
  final String valor;

  const _CursorProductosPrueba(this.valor);
}
