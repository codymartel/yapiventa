import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/subidor_de_imagenes.dart';
import 'package:mobile/features/productos/application/services/portada_producto.dart';
import 'package:mobile/features/productos/application/use_cases/crear_producto.dart';
import 'package:mobile/features/productos/application/use_cases/editar_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/foto_nueva.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_productos.dart';

class _Subidor implements SubidorDeImagenes {
  @override
  Future<ResultadoSubida> subir({
    required List<int> bytes,
    required String carpeta,
    required String nombreArchivo,
  }) async => ResultadoSubida(
    url: 'https://img.test/$nombreArchivo',
    identificador: 'id-$nombreArchivo',
  );

  @override
  Future<void> borrar(String identificador) async {}
}

class _Repositorio implements RepositorioProductos {
  Producto? guardado;

  @override
  Future<Producto> crearProducto(String negocioId, Producto producto) async {
    guardado = producto;
    return producto.copyWith(id: 'nuevo');
  }

  @override
  Future<String> guardarProducto(String negocioId, Producto producto) async {
    guardado = producto;
    return producto.id;
  }

  @override
  Future<PaginaProductos> obtenerPaginaProductos(
    String negocioId, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) => throw UnimplementedError();

  @override
  Future<void> eliminarProducto(String negocioId, String productoId) =>
      throw UnimplementedError();

  @override
  Future<void> toggleDisponible(
    String negocioId,
    String productoId,
    bool disponible,
  ) => throw UnimplementedError();
}

FotoNueva _foto(String nombre) =>
    FotoNueva(bytes: Uint8List.fromList([1]), nombreArchivo: nombre);

void main() {
  const luna = ModeloProducto(id: 'luna', nombre: 'Luna');
  const mar = ModeloProducto(id: 'mar', nombre: 'Mar');

  group('PortadaProducto', () {
    test('es la foto del primer modelo que la tiene', () {
      final portada = PortadaProducto.deModelos([
        luna,
        mar.copyWith(urlImagen: 'https://img.test/mar.jpg'),
      ]);
      expect(portada?.id, 'mar');
    });

    test('sin ninguna foto no hay portada', () {
      expect(PortadaProducto.deModelos([luna, mar]), isNull);
      expect(PortadaProducto.deModelos(const []), isNull);
    });
  });

  group('al crear con modelos', () {
    test(
      'la portada es la foto del primer modelo, sin foto principal',
      () async {
        final repositorio = _Repositorio();
        final crear = CrearProducto(
          repositorioProductos: repositorio,
          subidorDeImagenes: _Subidor(),
        );

        final creado = await crear(
          uid: 'u1',
          negocioId: 'n1',
          producto: Producto(
            negocioId: 'n1',
            nombre: 'Polo',
            modelos: const [luna, mar],
          ),
          fotosModelos: {'luna': _foto('luna.jpg'), 'mar': _foto('mar.jpg')},
        );

        expect(creado.urlImagen, 'https://img.test/luna.jpg');
        expect(creado.cloudinaryPublicId, 'id-luna.jpg');
        expect(creado.modelos.last.urlImagen, 'https://img.test/mar.jpg');
      },
    );

    test('sin modelos sigue valiendo la foto principal de siempre', () async {
      final repositorio = _Repositorio();
      final crear = CrearProducto(
        repositorioProductos: repositorio,
        subidorDeImagenes: _Subidor(),
      );

      final creado = await crear(
        uid: 'u1',
        negocioId: 'n1',
        producto: Producto(negocioId: 'n1', nombre: 'Café'),
        imagenBytes: Uint8List.fromList([1]),
        nombreArchivo: 'cafe.jpg',
      );

      expect(creado.urlImagen, 'https://img.test/cafe.jpg');
    });
  });

  group('al editar con modelos', () {
    test('la portada pasa a ser la del primer modelo', () async {
      final repositorio = _Repositorio();
      final editar = EditarProducto(repositorio, _Subidor());

      final editado = await editar(
        uid: 'u1',
        negocioId: 'n1',
        producto: Producto(
          id: 'p1',
          negocioId: 'n1',
          nombre: 'Polo',
          urlImagen: 'https://viejo/principal.jpg',
          modelos: const [
            ModeloProducto(
              id: 'luna',
              nombre: 'Luna',
              urlImagen: 'https://img.test/luna.jpg',
              cloudinaryPublicId: 'id-luna',
            ),
            mar,
          ],
        ),
        fotosModelos: {'mar': _foto('mar.jpg')},
      );

      expect(editado.urlImagen, 'https://img.test/luna.jpg');
      expect(editado.cloudinaryPublicId, 'id-luna');
      expect(repositorio.guardado?.urlImagen, 'https://img.test/luna.jpg');
    });

    test(
      'si ningún modelo tiene foto (antiguo) se conserva la principal',
      () async {
        final repositorio = _Repositorio();
        final editar = EditarProducto(repositorio, _Subidor());

        final editado = await editar(
          uid: 'u1',
          negocioId: 'n1',
          producto: Producto(
            id: 'p1',
            negocioId: 'n1',
            nombre: 'Polo',
            urlImagen: 'https://viejo/principal.jpg',
            modelos: const [luna],
          ),
        );

        expect(editado.urlImagen, 'https://viejo/principal.jpg');
      },
    );
  });
}
