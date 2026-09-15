import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/use_cases/eliminar_producto.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_productos.dart';

void main() {
  late _RepositorioProductosFake repositorioProductos;
  late EliminarProducto eliminarProducto;

  setUp(() {
    repositorioProductos = _RepositorioProductosFake();
    eliminarProducto = EliminarProducto(repositorioProductos);
  });

  test('elimina el documento del repositorio', () async {
    await eliminarProducto(negocioId: 'negocio-1', productoId: 'producto-1');

    expect(repositorioProductos.llamadasEliminar, 1);
    expect(repositorioProductos.ultimoNegocioId, 'negocio-1');
    expect(repositorioProductos.ultimoProductoId, 'producto-1');
  });

  test('no elimina si el identificador es vacío', () async {
    expect(
      () => eliminarProducto(negocioId: 'negocio-1', productoId: ' '),
      throwsArgumentError,
    );

    expect(repositorioProductos.llamadasEliminar, 0);
  });
}

class _RepositorioProductosFake implements RepositorioProductos {
  int llamadasEliminar = 0;
  String? ultimoNegocioId;
  String? ultimoProductoId;

  @override
  Future<void> eliminarProducto(String negocioId, String productoId) async {
    llamadasEliminar++;
    ultimoNegocioId = negocioId;
    ultimoProductoId = productoId;
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
  Future<PaginaProductos> obtenerPaginaProductos(
    String negocioId, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) {
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
