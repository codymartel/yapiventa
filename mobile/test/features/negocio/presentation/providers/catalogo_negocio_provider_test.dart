import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_catalogo_negocio.dart';
import 'package:mobile/features/negocio/presentation/providers/catalogo_negocio_provider.dart';

void main() {
  late _RepositorioCatalogoFake repository;
  late CatalogoNegocioProvider provider;

  CatalogoNegocio catalogo() => CatalogoNegocio(
    rubro: 'Bodega',
    categorias: const ['Bebidas'],
    unidadesMedida: const [
      UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
    ],
  );

  setUp(() {
    repository = _RepositorioCatalogoFake();
    provider = CatalogoNegocioProvider(
      uid: 'usuario-1',
      obtenerCatalogoNegocio: ObtenerCatalogoNegocio(repository),
    );
  });

  tearDown(() => provider.dispose());

  test('comparte una sola lectura concurrente y conserva la caché', () async {
    final pendiente = Completer<CatalogoNegocio>();
    repository.pendiente = pendiente;

    final primera = provider.cargar();
    final segunda = provider.cargar();

    expect(provider.cargando, isTrue);
    expect(repository.llamadas, 1);

    pendiente.complete(catalogo());
    await Future.wait([primera, segunda]);

    expect(provider.cargando, isFalse);
    expect(provider.cargado, isTrue);
    expect(provider.disponible, isTrue);
    expect(provider.catalogo?.categorias, ['Bebidas']);

    await provider.cargar();
    expect(repository.llamadas, 1);
  });

  test('muestra el error y permite reintentar', () async {
    repository.error = Exception('sin conexión');

    await provider.cargar();

    expect(provider.cargando, isFalse);
    expect(provider.cargado, isFalse);
    expect(provider.errorMessage, contains('sin conexión'));

    repository.error = null;
    final pendiente = Completer<CatalogoNegocio>();
    repository.pendiente = pendiente;
    final reintento = provider.reintentar();

    expect(provider.cargando, isTrue);
    expect(provider.errorMessage, isNull);
    expect(repository.llamadas, 2);

    pendiente.complete(catalogo());
    await reintento;

    expect(provider.cargando, isFalse);
    expect(provider.cargado, isTrue);
  });

  test('un catálogo vacío se carga pero no habilita el formulario', () async {
    repository.respuesta = CatalogoNegocio(
      rubro: 'Bodega',
      categorias: const [],
      unidadesMedida: const [],
    );

    await provider.cargar();

    expect(provider.cargado, isTrue);
    expect(provider.disponible, isFalse);
    expect(provider.errorMessage, isNull);
  });
}

class _RepositorioCatalogoFake implements RepositorioCatalogoNegocio {
  int llamadas = 0;
  Object? error;
  Completer<CatalogoNegocio>? pendiente;
  CatalogoNegocio respuesta = CatalogoNegocio(
    rubro: '',
    categorias: const [],
    unidadesMedida: const [],
  );

  @override
  Future<CatalogoNegocio> obtenerCatalogoNegocio(String uid) {
    llamadas++;
    final cargaPendiente = pendiente;
    if (cargaPendiente != null) return cargaPendiente.future;
    if (error != null) return Future.error(error!);
    return Future.value(respuesta);
  }
}
