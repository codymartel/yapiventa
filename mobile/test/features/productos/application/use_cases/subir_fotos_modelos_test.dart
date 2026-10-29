import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/subidor_de_imagenes.dart';
import 'package:mobile/features/productos/application/use_cases/subir_fotos_modelos.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/foto_nueva.dart';

class _SubidorFalso implements SubidorDeImagenes {
  final List<String> subidas = [];
  String? fallaEn;

  @override
  Future<ResultadoSubida> subir({
    required List<int> bytes,
    required String carpeta,
    required String nombreArchivo,
  }) async {
    if (nombreArchivo == fallaEn) throw Exception('sin red');
    subidas.add('$carpeta/$nombreArchivo');
    return ResultadoSubida(
      url: 'https://img.test/$nombreArchivo',
      identificador: 'id-$nombreArchivo',
    );
  }

  @override
  Future<void> borrar(String identificador) async {}
}

FotoNueva _foto(String nombre) =>
    FotoNueva(bytes: Uint8List.fromList([1, 2, 3]), nombreArchivo: nombre);

void main() {
  const modelos = [
    ModeloProducto(id: 'azul', nombre: 'Azul', urlImagen: 'https://viejo/azul'),
    ModeloProducto(id: 'rojo', nombre: 'Rojo'),
    ModeloProducto(id: 'verde', nombre: 'Verde'),
  ];

  test('sin fotos nuevas devuelve los mismos modelos y no sube nada', () async {
    final subidor = _SubidorFalso();

    final resultado = await subirFotosModelos(
      subidor: subidor,
      uid: 'u1',
      modelos: modelos,
      fotos: const {},
    );

    expect(resultado, same(modelos));
    expect(subidor.subidas, isEmpty);
  });

  test('sube solo los modelos con foto nueva y respeta el resto', () async {
    final subidor = _SubidorFalso();

    final resultado = await subirFotosModelos(
      subidor: subidor,
      uid: 'u1',
      modelos: modelos,
      fotos: {'rojo': _foto('rojo.jpg')},
    );

    expect(subidor.subidas, ['usuarios/u1/productos/rojo.jpg']);
    expect(resultado[0].urlImagen, 'https://viejo/azul');
    expect(resultado[1].urlImagen, 'https://img.test/rojo.jpg');
    expect(resultado[1].cloudinaryPublicId, 'id-rojo.jpg');
    expect(resultado[2].urlImagen, isEmpty);
  });

  test('una foto nueva reemplaza la guardada del mismo modelo', () async {
    final resultado = await subirFotosModelos(
      subidor: _SubidorFalso(),
      uid: 'u1',
      modelos: modelos,
      fotos: {'azul': _foto('azul2.jpg')},
    );

    expect(resultado.first.urlImagen, 'https://img.test/azul2.jpg');
  });

  test(
    'si una foto falla el error sube y no se guarda nada a medias',
    () async {
      final subidor = _SubidorFalso()..fallaEn = 'verde.jpg';

      await expectLater(
        subirFotosModelos(
          subidor: subidor,
          uid: 'u1',
          modelos: modelos,
          fotos: {'rojo': _foto('rojo.jpg'), 'verde': _foto('verde.jpg')},
        ),
        throwsException,
      );
    },
  );

  test('una foto sin nombre de archivo se rechaza', () async {
    await expectLater(
      subirFotosModelos(
        subidor: _SubidorFalso(),
        uid: 'u1',
        modelos: modelos,
        fotos: {'rojo': _foto('  ')},
      ),
      throwsArgumentError,
    );
  });
}
