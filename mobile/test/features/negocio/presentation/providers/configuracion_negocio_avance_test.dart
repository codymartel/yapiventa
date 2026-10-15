import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

/// Repositorio que nunca responde, para comprobar el timeout de 8 s.
class _RepoColgado extends NegocioRepository {
  _RepoColgado({required super.firestore});

  @override
  Future<void> guardarAvanceCatalogoVenta({
    required String uid,
    required CatalogoVentaPersistido catalogoVenta,
    String? negocioId,
  }) {
    return Completer<void>().future;
  }
}

/// Repositorio conmutable: falla hasta que se le permite escribir, para
/// comprobar que tras un fallo el reintento sí escribe.
class _RepoConmutable extends NegocioRepository {
  _RepoConmutable({required super.firestore});

  bool fallar = true;
  int escrituras = 0;

  @override
  Future<void> guardarAvanceCatalogoVenta({
    required String uid,
    required CatalogoVentaPersistido catalogoVenta,
    String? negocioId,
  }) async {
    if (fallar) throw StateError('sin conexión');
    escrituras++;
    return super.guardarAvanceCatalogoVenta(
      uid: uid,
      catalogoVenta: catalogoVenta,
      negocioId: negocioId,
    );
  }
}

Map<String, dynamic> _inicialHidratada() => {
  'catalogoVenta':
      CatalogoVentaPersistido.desdePreset(PresetsVenta.obtener('Bodega'))
          .toMap(),
};

ConfiguracionNegocioProvider _provider({
  required NegocioRepository repository,
  Map<String, dynamic>? configuracionInicial,
}) {
  return ConfiguracionNegocioProvider(
    rubro: 'Bodega',
    negocioId: 'neg-1',
    configuracionInicial: configuracionInicial,
    repository: repository,
  );
}

/// Toca el catálogo por el camino del usuario (desactiva una medida activa
/// o voltea una presentación no obligatoria).
void _tocarCatalogo(ConfiguracionNegocioProvider provider) {
  for (final familia in FamiliaUnidad.values) {
    if (provider.medidaActiva(familia)) {
      provider.establecerMedidaActiva(familia, activa: false);
      return;
    }
  }
  final candidata = provider.presentaciones.firstWhere((p) => !p.obligatoria);
  provider.establecerPresentacionActiva(candidata.id, activa: !candidata.activa);
}

/// Crea el documento del negocio (como lo deja la elección de rubro).
Future<void> _negocioExistente(FakeFirebaseFirestore fake) =>
    fake.collection('negocios').doc('neg-1').set({'rubro': 'Bodega'});

Future<Map<String, dynamic>?> _docAvance(FakeFirebaseFirestore fake) async {
  final doc = await fake.collection('negocios').doc('neg-1').get();
  if (!doc.exists) return null;
  return doc.data();
}

void main() {
  test('sin tocar no escribe y avanza', () async {
    final fake = FakeFirebaseFirestore();
    final provider = _provider(
      repository: NegocioRepository(firestore: fake),
      configuracionInicial: _inicialHidratada(),
    );

    expect(await provider.guardarAvanceCatalogoVenta('u'), isTrue);
    expect(await _docAvance(fake), isNull);
    expect(provider.errorAvance, isNull);

    provider.siguiente();
    expect(provider.pasoActual, 1);
  });

  test('tocado e hidratado escribe y avanza', () async {
    final fake = FakeFirebaseFirestore();
    await _negocioExistente(fake);
    final provider = _provider(
      repository: NegocioRepository(firestore: fake),
      configuracionInicial: _inicialHidratada(),
    );
    _tocarCatalogo(provider);

    expect(await provider.guardarAvanceCatalogoVenta('u'), isTrue);
    final datos = await _docAvance(fake);
    expect(datos, isNotNull);
    expect(datos!['catalogoVenta'], isA<Map>());
    // Lo tocado quedó persistido: al menos una medida o presentación inactiva.
    final releido = CatalogoVentaPersistido.desdeMapa(datos['catalogoVenta'])!;
    final hayInactiva =
        releido.medidas.any((m) => !m.activa) ||
        releido.presentaciones.any((p) => !p.activa);
    expect(hayInactiva, isTrue);

    provider.siguiente();
    expect(provider.pasoActual, 1);
  });

  test('negocio nuevo (sin catálogo guardado) también escribe al avanzar', () async {
    final fake = FakeFirebaseFirestore();
    await _negocioExistente(fake);
    final provider = _provider(
      repository: NegocioRepository(firestore: fake),
    );
    _tocarCatalogo(provider);

    // Lo activado/desactivado llega a Firestore sin esperar a Finalizar.
    expect(await provider.guardarAvanceCatalogoVenta('u'), isTrue);
    final datos = await _docAvance(fake);
    expect(datos!['catalogoVenta'], isA<Map>());
    expect(datos['rubro'], 'Bodega');

    provider.siguiente();
    expect(provider.pasoActual, 1);
  });

  test('no crea el documento si el negocio aún no existe', () async {
    final fake = FakeFirebaseFirestore();
    final provider = _provider(
      repository: NegocioRepository(firestore: fake),
    );
    _tocarCatalogo(provider);

    expect(await provider.guardarAvanceCatalogoVenta('u'), isTrue);
    expect(await _docAvance(fake), isNull);

    provider.siguiente();
    expect(provider.pasoActual, 1);
  });

  test('falla al escribir deja errorAvance, no avanza y reintenta', () async {
    final fake = FakeFirebaseFirestore();
    await _negocioExistente(fake);
    final repo = _RepoConmutable(firestore: fake);
    final provider = _provider(
      repository: repo,
      configuracionInicial: _inicialHidratada(),
    );
    _tocarCatalogo(provider);

    expect(await provider.guardarAvanceCatalogoVenta('u'), isFalse);
    expect(provider.errorAvance, isNotNull);
    expect(provider.pasoActual, 0);
    expect(provider.guardandoAvance, isFalse);
    expect(repo.escrituras, 0);

    // El reintento sí escribe: el flag de tocado sobrevivió al fallo.
    repo.fallar = false;
    expect(await provider.guardarAvanceCatalogoVenta('u'), isTrue);
    expect(repo.escrituras, 1);
    expect(await _docAvance(fake), isNotNull);

    provider.siguiente();
    expect(provider.pasoActual, 1);
  });

  test('colgado hace timeout con errorAvance y no avanza', () async {
    final fake = FakeFirebaseFirestore();
    final provider = _provider(
      repository: _RepoColgado(firestore: fake),
      configuracionInicial: _inicialHidratada(),
    );
    _tocarCatalogo(provider);

    expect(await provider.guardarAvanceCatalogoVenta('u'), isFalse);
    expect(provider.errorAvance, contains('tardó'));
    expect(provider.pasoActual, 0);
    expect(provider.guardandoAvance, isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
