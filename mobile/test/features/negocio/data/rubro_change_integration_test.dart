import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

void main() {
  late _MergeAwareFakeFirebaseFirestore firestore;
  late NegocioRepository repository;

  setUp(() {
    firestore = _MergeAwareFakeFirebaseFirestore();
    repository = NegocioRepository(firestore: firestore);
  });

  test(
    'cambiar de Restaurante a Accesorios: provider tiene solo presentaciones y medidas de Accesorios',
    () async {
      final catalogoRestaurante = CatalogoVentaPersistido(
        presentaciones: [
          OpcionPresentacion(
            id: 'unidad',
            nombre: 'Unidad',
            formatos: [FormatoPresentacion(valorBase: 1, familia: FamiliaUnidad.conteo, unidadVisible: RegistroUnidades.unidad)],
            activa: true,
            obligatoria: false,
          ),
          OpcionPresentacion(
            id: 'porcion',
            nombre: 'Porción',
            formatos: [FormatoPresentacion(valorBase: 1, familia: FamiliaUnidad.conteo, unidadVisible: RegistroUnidades.unidad)],
            activa: true,
            obligatoria: true,
          ),
          OpcionPresentacion(
            id: 'plato',
            nombre: 'Plato',
            formatos: [FormatoPresentacion(valorBase: 1, familia: FamiliaUnidad.conteo, unidadVisible: RegistroUnidades.unidad)],
            activa: true,
            obligatoria: true,
          ),
        ],
        medidas: [
          MedidaVentaPersistida(
            id: 'peso',
            nombre: 'Peso',
            familia: FamiliaUnidad.peso,
            unidadBase: RegistroUnidades.kg,
            unidadVisual: RegistroUnidades.kg,
            minimoBase: 100,
            incrementoBase: 50,
            cantidadesRapidasBase: const [250, 500, 750, 1000],
            permiteCantidad: true,
            permiteMonto: true,
            activa: false,
            obligatoria: false,
          ),
        ],
      );

      final negocioId = await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {
          'rubro': 'Restaurante',
          'nombreNegocio': 'Restaurante Ana',
          'catalogoVenta': catalogoRestaurante.toMap(),
          'categorias': ['Entradas', 'Platos principales'],
          'unidadesMedida': [
            {'nombre': 'Unidad', 'tipo': 'entera', 'fraccionesPermitidas': <String>[], 'esOpcional': false},
          ],
          'webActiva': true,
        },
      );

      await repository.guardarRubro('usuario-1', 'Accesorios y regalos');

      final datos = (await firestore.collection('negocios').doc(negocioId).get())
          .data()!;

      final provider = ConfiguracionNegocioProvider(
        rubro: 'Accesorios y regalos',
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
        configuracionInicial: datos,
      );

      final idsPresentaciones = provider.catalogoVenta.presentaciones.map((p) => p.id).toList();

      expect(idsPresentaciones, contains('unidad'));
      expect(idsPresentaciones, contains('par'));
      expect(idsPresentaciones, contains('set'));
      expect(idsPresentaciones, contains('juego'));
      expect(idsPresentaciones, contains('caja'));
      expect(idsPresentaciones, contains('paquete'));
      expect(idsPresentaciones, contains('bolsa'));
      expect(idsPresentaciones, isNot(contains('porcion')));
      expect(idsPresentaciones, isNot(contains('plato')));

      expect(provider.catalogoVenta.medidas.length, 1);
      expect(provider.catalogoVenta.medidas.first.familia, FamiliaUnidad.longitud);

      expect(provider.categorias, ['Bisutería', 'Carteras', 'Peluches', 'Regalos', 'Detalles']);
    },
  );

  test(
    'cambiar de Bodega a Ropa: provider tiene solo presentaciones y medidas de Ropa',
    () async {
      final catalogoBodega = CatalogoVentaPersistido(
        presentaciones: [
          OpcionPresentacion(
            id: 'unidad',
            nombre: 'Unidad',
            formatos: [FormatoPresentacion(valorBase: 1, familia: FamiliaUnidad.conteo, unidadVisible: RegistroUnidades.unidad)],
            activa: true,
            obligatoria: false,
          ),
          OpcionPresentacion(
            id: 'botella',
            nombre: 'Botella',
            formatos: [FormatoPresentacion(valorBase: 250, familia: FamiliaUnidad.volumen, unidadVisible: RegistroUnidades.ml)],
            activa: true,
            obligatoria: true,
          ),
        ],
        medidas: [
          MedidaVentaPersistida(
            id: 'peso',
            nombre: 'Peso',
            familia: FamiliaUnidad.peso,
            unidadBase: RegistroUnidades.kg,
            unidadVisual: RegistroUnidades.kg,
            minimoBase: 100,
            incrementoBase: 50,
            cantidadesRapidasBase: const [250, 500, 750, 1000],
            permiteCantidad: true,
            permiteMonto: true,
            activa: true,
            obligatoria: false,
          ),
          MedidaVentaPersistida(
            id: 'volumen',
            nombre: 'Volumen',
            familia: FamiliaUnidad.volumen,
            unidadBase: RegistroUnidades.L,
            unidadVisual: RegistroUnidades.L,
            minimoBase: 250,
            incrementoBase: 250,
            cantidadesRapidasBase: const [250, 500, 750, 1000],
            permiteCantidad: true,
            permiteMonto: false,
            activa: true,
            obligatoria: false,
          ),
        ],
      );

      final negocioId = await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {
          'rubro': 'Bodega',
          'nombreNegocio': 'Bodega Ana',
          'catalogoVenta': catalogoBodega.toMap(),
          'categorias': ['Abarrotes', 'Bebidas'],
          'unidadesMedida': [
            {'nombre': 'kg', 'tipo': 'fraccionaria', 'fraccionesPermitidas': ['0.5', '1'], 'esOpcional': false},
          ],
          'webActiva': true,
        },
      );

      await repository.guardarRubro('usuario-1', 'Ropa');

      final datos = (await firestore.collection('negocios').doc(negocioId).get())
          .data()!;

      final provider = ConfiguracionNegocioProvider(
        rubro: 'Ropa',
        repository: NegocioRepository(firestore: FakeFirebaseFirestore()),
        configuracionInicial: datos,
      );

      expect(provider.catalogoVenta.medidas.length, 1);
      expect(provider.catalogoVenta.medidas.first.familia, FamiliaUnidad.longitud);

      expect(
        provider.catalogoVenta.presentaciones.map((p) => p.id).toList(),
        isNot(contains('botella')),
      );
      expect(
        provider.catalogoVenta.presentaciones.map((p) => p.id).toList(),
        isNot(contains('volumen')),
      );
      expect(
        provider.catalogoVenta.medidas.map((m) => m.id).toList(),
        isNot(contains('peso')),
      );
      expect(
        provider.catalogoVenta.medidas.map((m) => m.id).toList(),
        isNot(contains('volumen')),
      );
    },
  );

  test(
    'guardarRubro con mismo rubro NO elimina catalogoVenta',
    () async {
      final catalogoVenta = CatalogoVentaPersistido(
        presentaciones: [
          OpcionPresentacion(
            id: 'unidad',
            nombre: 'Unidad',
            formatos: [FormatoPresentacion(valorBase: 1, familia: FamiliaUnidad.conteo, unidadVisible: RegistroUnidades.unidad)],
            activa: true,
            obligatoria: false,
          ),
        ],
        medidas: [],
      );

      final negocioId = await _prepararNegocio(
        firestore,
        'usuario-1',
        datos: {
          'rubro': 'Bodega',
          'nombreNegocio': 'Bodega Ana',
          'catalogoVenta': catalogoVenta.toMap(),
          'categorias': ['Abarrotes'],
          'unidadesMedida': [
            {'nombre': 'kg', 'tipo': 'fraccionaria', 'fraccionesPermitidas': <String>[], 'esOpcional': false},
          ],
          'webActiva': true,
        },
      );

      await repository.guardarRubro('usuario-1', 'Bodega');

      final datos = (await firestore.collection('negocios').doc(negocioId).get())
          .data()!;
      expect(datos['rubro'], 'Bodega');
      expect(datos['catalogoVenta'], isNotNull);
      expect((datos['catalogoVenta'] as Map)['presentaciones'], isNotNull);
    },
  );
}

Future<String> _prepararNegocio(
  FakeFirebaseFirestore firestore,
  String uid, {
  Map<String, dynamic> datos = const {},
}) async {
  await _guardarPerfilConNegocioId(firestore, uid);
  final negocioId = 'negocio-$uid';
  await firestore.collection('negocios').doc(negocioId).set({
    'propietarioUid': uid,
    ...datos,
  });
  return negocioId;
}

// fake_cloud_firestore 3.1.0 ignora SetOptions en transacciones.
class _MergeAwareFakeFirebaseFirestore extends FakeFirebaseFirestore {
  int negociosCollectionAccesses = 0;
  int usersCollectionAccesses = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'negocios') negociosCollectionAccesses++;
    if (collectionPath == 'users') usersCollectionAccesses++;
    return super.collection(collectionPath);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _MergeAwareTransaction();
    final result = await transactionHandler(transaction);
    await transaction.commit();
    return result;
  }
}

class _MergeAwareTransaction implements Transaction {
  final List<Future<void> Function()> _writes = [];

  Future<void> commit() async {
    for (final write in _writes) {
      await write();
    }
  }

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) {
    return documentReference.get();
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _writes.add(() => documentReference.set(data, options));
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<String, dynamic> data,
  ) {
    _writes.add(() => documentReference.update(data));
    return this;
  }

  @override
  Transaction delete(DocumentReference<Object?> documentReference) {
    _writes.add(documentReference.delete);
    return this;
  }
}

Future<void> _guardarPerfilConNegocioId(
  FakeFirebaseFirestore firestore,
  String uid,
) async {
  await firestore.collection('users').doc(uid).set({
    'email': 'ana@example.com',
    'negocioId': 'negocio-$uid',
  });
}
