import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_negocio.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_catalogo_venta.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
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

  CatalogoVentaPersistido venta() =>
      CatalogoVentaPersistido(presentaciones: const [], medidas: const []);

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

  group('catálogo de venta', () {
    test('sin dependencia inyectada no se lee y queda sin datos', () async {
      await provider.cargarVenta();

      expect(repository.llamadasVenta, 0);
      expect(provider.ventaCargada, isFalse);
      expect(provider.catalogoVenta, isNull);
      expect(provider.cargandoVenta, isFalse);
      expect(provider.ventaErrorMessage, isNull);
    });

    test('inyectado: carga una vez, comparte lectura y conserva la caché', () async {
      final conVenta = CatalogoNegocioProvider(
        uid: 'usuario-1',
        obtenerCatalogoNegocio: ObtenerCatalogoNegocio(repository),
        obtenerCatalogoVenta: ObtenerCatalogoVenta(repository),
      );
      addTearDown(conVenta.dispose);

      repository.respuestaVenta = venta();

      final primera = conVenta.cargarVenta();
      final segunda = conVenta.cargarVenta();

      expect(conVenta.cargandoVenta, isTrue);
      expect(repository.llamadasVenta, 1);

      await Future.wait([primera, segunda]);

      expect(conVenta.cargandoVenta, isFalse);
      expect(conVenta.ventaCargada, isTrue);
      expect(conVenta.catalogoVenta, isNotNull);

      await conVenta.cargarVenta();
      expect(repository.llamadasVenta, 1);
    });

    test('cargar() dispara también el catálogo de venta', () async {
      final conVenta = CatalogoNegocioProvider(
        uid: 'usuario-1',
        obtenerCatalogoNegocio: ObtenerCatalogoNegocio(repository),
        obtenerCatalogoVenta: ObtenerCatalogoVenta(repository),
      );
      addTearDown(conVenta.dispose);

      repository.respuestaVenta = venta();
      await conVenta.cargar();

      expect(conVenta.cargado, isTrue);
      expect(conVenta.ventaCargada, isTrue);
      expect(repository.llamadasVenta, 1);
    });

    test('el error de venta no ensucia el catálogo legacy', () async {
      final conVenta = CatalogoNegocioProvider(
        uid: 'usuario-1',
        obtenerCatalogoNegocio: ObtenerCatalogoNegocio(repository),
        obtenerCatalogoVenta: ObtenerCatalogoVenta(repository),
      );
      addTearDown(conVenta.dispose);

      repository.errorVenta = Exception('catálogo caído');
      await conVenta.cargar();

      expect(conVenta.cargado, isTrue);
      expect(conVenta.errorMessage, isNull);
      expect(conVenta.ventaCargada, isFalse);
      expect(conVenta.ventaErrorMessage, contains('catálogo caído'));
    });

    test('reintentarVenta recupera tras el error', () async {
      final conVenta = CatalogoNegocioProvider(
        uid: 'usuario-1',
        obtenerCatalogoNegocio: ObtenerCatalogoNegocio(repository),
        obtenerCatalogoVenta: ObtenerCatalogoVenta(repository),
      );
      addTearDown(conVenta.dispose);

      repository.errorVenta = Exception('catálogo caído');
      await conVenta.cargarVenta();
      expect(conVenta.ventaCargada, isFalse);

      repository.errorVenta = null;
      repository.respuestaVenta = venta();
      await conVenta.reintentarVenta();

      expect(conVenta.cargandoVenta, isFalse);
      expect(conVenta.ventaCargada, isTrue);
      expect(conVenta.ventaErrorMessage, isNull);
      expect(repository.llamadasVenta, 2);
    });
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

  int llamadasVenta = 0;
  Object? errorVenta;
  CatalogoVentaPersistido? respuestaVenta;

  @override
  Future<CatalogoNegocio> obtenerCatalogoNegocio(String uid) {
    llamadas++;
    final cargaPendiente = pendiente;
    if (cargaPendiente != null) return cargaPendiente.future;
    if (error != null) return Future.error(error!);
    return Future.value(respuesta);
  }

  @override
  Future<CatalogoVentaPersistido?> obtenerCatalogoVenta(
    String uid, {
    String? negocioId,
  }) async {
    llamadasVenta++;
    if (errorVenta != null) return Future.error(errorVenta!);
    return respuestaVenta;
  }
}
