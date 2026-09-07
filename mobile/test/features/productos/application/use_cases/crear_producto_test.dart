import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/subidor_de_imagenes.dart';
import 'package:mobile/features/productos/application/use_cases/crear_producto.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_productos.dart';

void main() {
  late _RepositorioProductosFake repositorioProductos;
  late _SubidorDeImagenesFake subidorDeImagenes;
  late CrearProducto crearProducto;

  Producto producto() =>
      Producto(negocioId: '', nombre: 'Cafe', precio: 12.5, stock: 4);

  setUp(() {
    repositorioProductos = _RepositorioProductosFake();
    subidorDeImagenes = _SubidorDeImagenesFake();
    crearProducto = CrearProducto(
      repositorioProductos: repositorioProductos,
      subidorDeImagenes: subidorDeImagenes,
    );
  });

  test('sin imagen omite la subida y guarda una sola vez', () async {
    final guardado = await crearProducto(
      uid: 'usuario-1',
      producto: producto(),
    );

    expect(subidorDeImagenes.llamadas, 0);
    expect(repositorioProductos.llamadas, 1);
    expect(repositorioProductos.ultimoProducto?.negocioId, 'usuario-1');
    expect(guardado.id, 'producto-1');
  });

  test('con imagen utiliza la URL e identificador y guarda una vez', () async {
    final guardado = await crearProducto(
      uid: 'usuario-1',
      producto: producto(),
      imagenBytes: Uint8List.fromList([1, 2, 3]),
      nombreArchivo: 'cafe.jpg',
    );

    expect(subidorDeImagenes.llamadas, 1);
    expect(subidorDeImagenes.ultimaCarpeta, 'usuarios/usuario-1/productos');
    expect(subidorDeImagenes.ultimoNombreArchivo, 'cafe.jpg');
    expect(repositorioProductos.llamadas, 1);
    expect(guardado.urlImagen, 'https://imagenes.test/cafe.jpg');
    expect(guardado.cloudinaryPublicId, 'usuarios/usuario-1/cafe');
  });

  test('si falla la subida propaga el error y no guarda', () async {
    final error = Exception('Servicio de imagen no disponible');
    subidorDeImagenes.error = error;

    await expectLater(
      crearProducto(
        uid: 'usuario-1',
        producto: producto(),
        imagenBytes: Uint8List.fromList([1]),
        nombreArchivo: 'cafe.jpg',
      ),
      throwsA(same(error)),
    );
    expect(repositorioProductos.llamadas, 0);
  });

  test(
    'si falla Firestore propaga el error y no informa un producto',
    () async {
      final error = Exception('Firestore no disponible');
      repositorioProductos.error = error;

      await expectLater(
        crearProducto(
          uid: 'usuario-1',
          producto: producto(),
          imagenBytes: Uint8List.fromList([1]),
          nombreArchivo: 'cafe.jpg',
        ),
        throwsA(same(error)),
      );
      expect(subidorDeImagenes.llamadas, 1);
      expect(repositorioProductos.llamadas, 1);
    },
  );
}

class _RepositorioProductosFake implements RepositorioProductos {
  int llamadas = 0;
  String? ultimoUid;
  Producto? ultimoProducto;
  Object? error;

  @override
  Future<PaginaProductos> obtenerPaginaProductos(
    String uid, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Producto> crearProducto(String uid, Producto producto) async {
    llamadas++;
    ultimoUid = uid;
    ultimoProducto = producto;
    if (error != null) throw error!;
    return producto.copyWith(id: 'producto-1');
  }

  @override
  Future<String> guardarProducto(String uid, Producto producto) {
    throw UnimplementedError();
  }

  @override
  Future<void> eliminarProducto(String uid, String productoId) {
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

class _SubidorDeImagenesFake implements SubidorDeImagenes {
  int llamadas = 0;
  String? ultimaCarpeta;
  String? ultimoNombreArchivo;
  Object? error;

  @override
  Future<ResultadoSubida> subir({
    required List<int> bytes,
    required String carpeta,
    required String nombreArchivo,
  }) async {
    llamadas++;
    ultimaCarpeta = carpeta;
    ultimoNombreArchivo = nombreArchivo;
    if (error != null) throw error!;
    return const ResultadoSubida(
      url: 'https://imagenes.test/cafe.jpg',
      identificador: 'usuarios/usuario-1/cafe',
    );
  }

  @override
  Future<void> borrar(String identificador) async {}
}
