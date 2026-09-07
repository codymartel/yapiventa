import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/subidor_de_imagenes.dart';
import 'package:mobile/features/productos/application/use_cases/editar_producto.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_productos.dart';

void main() {
  late _RepositorioProductosFake repositorioProductos;
  late _SubidorDeImagenesFake subidorDeImagenes;
  late EditarProducto editarProducto;

  Producto producto() => Producto(
    id: 'producto-1',
    negocioId: 'negocio-anterior',
    nombre: 'Cafe',
    precio: 12.5,
    stock: 4,
    urlImagen: 'https://imagenes.test/anterior.jpg',
    cloudinaryPublicId: 'productos/anterior',
  );

  setUp(() {
    repositorioProductos = _RepositorioProductosFake();
    subidorDeImagenes = _SubidorDeImagenesFake();
    editarProducto = EditarProducto(repositorioProductos, subidorDeImagenes);
  });

  test('edita sin imagen y conserva la imagen anterior', () async {
    final guardado = await editarProducto(
      uid: 'usuario-1',
      producto: producto().copyWith(nombre: 'Cafe editado'),
    );

    expect(subidorDeImagenes.llamadas, 0);
    expect(repositorioProductos.llamadasGuardado, 1);
    expect(repositorioProductos.ultimoUid, 'usuario-1');
    expect(guardado.negocioId, 'usuario-1');
    expect(guardado.nombre, 'Cafe editado');
    expect(guardado.urlImagen, 'https://imagenes.test/anterior.jpg');
    expect(guardado.cloudinaryPublicId, 'productos/anterior');
    expect(repositorioProductos.ultimoProducto, same(guardado));
  });

  test('edita con imagen y guarda la nueva URL e identificador', () async {
    final guardado = await editarProducto(
      uid: 'usuario-1',
      producto: producto(),
      imagenBytes: Uint8List.fromList([1, 2, 3]),
      nombreArchivo: 'cafe-nuevo.jpg',
    );

    expect(subidorDeImagenes.llamadas, 1);
    expect(subidorDeImagenes.ultimaCarpeta, 'usuarios/usuario-1/productos');
    expect(subidorDeImagenes.ultimoNombreArchivo, 'cafe-nuevo.jpg');
    expect(repositorioProductos.llamadasGuardado, 1);
    expect(guardado.urlImagen, 'https://imagenes.test/nueva.jpg');
    expect(guardado.cloudinaryPublicId, 'productos/nueva');
    expect(repositorioProductos.ultimoProducto, same(guardado));
  });

  test('no escribe si el producto no tiene identificador', () async {
    await expectLater(
      editarProducto(
        uid: 'usuario-1',
        producto: producto().copyWith(id: ''),
      ),
      throwsArgumentError,
    );

    expect(subidorDeImagenes.llamadas, 0);
    expect(repositorioProductos.llamadasGuardado, 0);
  });
}

class _RepositorioProductosFake implements RepositorioProductos {
  int llamadasGuardado = 0;
  String? ultimoUid;
  Producto? ultimoProducto;

  @override
  Future<String> guardarProducto(String uid, Producto producto) async {
    llamadasGuardado++;
    ultimoUid = uid;
    ultimoProducto = producto;
    return producto.id;
  }

  @override
  Future<Producto> crearProducto(String uid, Producto producto) {
    throw UnimplementedError();
  }

  @override
  Future<void> eliminarProducto(String uid, String productoId) {
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

class _SubidorDeImagenesFake implements SubidorDeImagenes {
  int llamadas = 0;
  String? ultimaCarpeta;
  String? ultimoNombreArchivo;

  @override
  Future<ResultadoSubida> subir({
    required List<int> bytes,
    required String carpeta,
    required String nombreArchivo,
  }) async {
    llamadas++;
    ultimaCarpeta = carpeta;
    ultimoNombreArchivo = nombreArchivo;
    return const ResultadoSubida(
      url: 'https://imagenes.test/nueva.jpg',
      identificador: 'productos/nueva',
    );
  }

  @override
  Future<void> borrar(String identificador) async {}
}
