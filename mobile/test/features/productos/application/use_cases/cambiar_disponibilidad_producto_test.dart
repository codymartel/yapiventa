import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/use_cases/cambiar_disponibilidad_producto.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_productos.dart';

void main() {
  late _RepositorioProductosFake repositorioProductos;
  late CambiarDisponibilidadProducto cambiarDisponibilidad;

  setUp(() {
    repositorioProductos = _RepositorioProductosFake();
    cambiarDisponibilidad = CambiarDisponibilidadProducto(repositorioProductos);
  });

  test('cambia únicamente la disponibilidad mediante el repositorio', () async {
    await cambiarDisponibilidad(
      negocioId: 'negocio-1',
      productoId: 'producto-1',
      disponible: false,
    );

    expect(repositorioProductos.llamadas, 1);
    expect(repositorioProductos.ultimoNegocioId, 'negocio-1');
    expect(repositorioProductos.ultimoProductoId, 'producto-1');
    expect(repositorioProductos.ultimaDisponibilidad, isFalse);
  });

  test('no actualiza si el identificador es vacío', () {
    expect(
      () => cambiarDisponibilidad(
        negocioId: 'negocio-1',
        productoId: ' ',
        disponible: false,
      ),
      throwsArgumentError,
    );

    expect(repositorioProductos.llamadas, 0);
  });
}

class _RepositorioProductosFake implements RepositorioProductos {
  int llamadas = 0;
  String? ultimoNegocioId;
  String? ultimoProductoId;
  bool? ultimaDisponibilidad;

  @override
  Future<void> toggleDisponible(
    String negocioId,
    String productoId,
    bool disponible,
  ) async {
    llamadas++;
    ultimoNegocioId = negocioId;
    ultimoProductoId = productoId;
    ultimaDisponibilidad = disponible;
  }

  @override
  Future<Producto> crearProducto(String negocioId, Producto producto) {
    throw UnimplementedError();
  }

  @override
  Future<void> eliminarProducto(String negocioId, String productoId) {
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
}
