import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_catalogo_negocio.dart';

void main() {
  test('delega el uid y devuelve el catálogo del repositorio', () async {
    final catalogo = CatalogoNegocio(
      rubro: 'Bodega',
      categorias: const ['Bebidas'],
      unidadesMedida: const [],
    );
    final repository = _RepositorioCatalogoFake(catalogo);
    final obtenerCatalogo = ObtenerCatalogoNegocio(repository);

    final resultado = await obtenerCatalogo('usuario-1');

    expect(resultado, same(catalogo));
    expect(repository.llamadas, 1);
    expect(repository.ultimoUid, 'usuario-1');
  });

  test('propaga el error del repositorio', () async {
    final error = Exception('Firestore no disponible');
    final repository = _RepositorioCatalogoFake.error(error);

    await expectLater(
      ObtenerCatalogoNegocio(repository)('usuario-1'),
      throwsA(same(error)),
    );
  });
}

class _RepositorioCatalogoFake implements RepositorioCatalogoNegocio {
  final CatalogoNegocio? respuesta;
  final Object? error;
  int llamadas = 0;
  String? ultimoUid;

  _RepositorioCatalogoFake(this.respuesta) : error = null;

  _RepositorioCatalogoFake.error(this.error) : respuesta = null;

  @override
  Future<CatalogoNegocio> obtenerCatalogoNegocio(String uid) async {
    llamadas++;
    ultimoUid = uid;
    if (error != null) throw error!;
    return respuesta!;
  }
}
