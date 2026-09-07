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
    await eliminarProducto(uid: 'usuario-1', productoId: 'producto-1');

    expect(repositorioProductos.llamadasEliminar, 1);
    expect(repositorioProductos.ultimoUid, 'usuario-1');
    expect(repositorioProductos.ultimoProductoId, 'producto-1');
  });

  test('no elimina si el identificador es vacío', () async {
    expect(
      () => eliminarProducto(uid: 'usuario-1', productoId: ' '),
      throwsArgumentError,
    );

    expect(repositorioProductos.llamadasEliminar, 0);
  });
}

class _RepositorioProductosFake implements RepositorioProductos {
  int llamadasEliminar = 0;
  String? ultimoUid;
  String? ultimoProductoId;

  @override
  Future<void> eliminarProducto(String uid, String productoId) async {
    llamadasEliminar++;
    ultimoUid = uid;
    ultimoProductoId = productoId;
  }

  @override
  Future<Producto> crearProducto(String uid, Producto producto) {
    throw UnimplementedError();
  }

  @override
  Future<String> guardarProducto(String uid, Producto producto) {
    throw UnimplementedError();
  }

  @override
  Future<PaginaProductos> obtenerPaginaProductos(
    String uid, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> toggleDisponible(
    String uid,
    String productoId,
    bool disponible,
  ) {
    throw UnimplementedError();
  }
}
