import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/relleno_catalogo_caja.dart';
import 'package:mobile/features/productos/application/use_cases/preparar_catalogo_caja.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/data/relleno_catalogo_caja_repository.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';

void main() {
  late FakeFirebaseFirestore db;
  late RellenoCatalogoCajaRepository repo;

  DocumentReference<Map<String, dynamic>> negocio([String id = _negocio]) =>
      db.collection('negocios').doc(id);

  CollectionReference<Map<String, dynamic>> productos([String id = _negocio]) =>
      negocio(id).collection('productos');

  /// Un producto como se guardaba ANTES de 3g: sin los campos del catálogo.
  Future<void> guardarViejo(Producto p, {String negocioId = _negocio}) {
    final datos = ProductoFirestoreMapper.paraFirestore(p)
      ..['negocioId'] = negocioId
      ..remove('nombreBusqueda')
      ..remove('tipoCaja');
    return productos(negocioId).doc(p.id).set(datos);
  }

  Future<Map<String, dynamic>> leer(String id) async =>
      (await productos().doc(id).get()).data()!;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = RellenoCatalogoCajaRepository(db);
    await negocio().set({'propietarioUid': 'dueno1', 'webActiva': false});
  });

  group('la marca «catálogo listo»', () {
    test('un negocio nuevo no la tiene', () async {
      expect(await repo.catalogoListo(_negocio), isFalse);
    });

    test('un negocio que no existe tampoco', () async {
      expect(await repo.catalogoListo('no-existe'), isFalse);
    });

    test('rellenar la pone y no borra los demás datos del negocio', () async {
      await repo.rellenar(_negocio);

      expect(await repo.catalogoListo(_negocio), isTrue);
      final datos = (await negocio().get()).data()!;
      expect(datos['propietarioUid'], 'dueno1');
      expect(datos['webActiva'], isFalse);
    });
  });

  group('rellenar productos viejos', () {
    test('les pone nombreBusqueda, tipoCaja y vendidos en 0', () async {
      await guardarViejo(productoSimple(nombre: 'Piña Dulce'));
      await guardarViejo(quesoPorMedida());
      await guardarViejo(poloConModelos());
      await guardarViejo(comboGaseosaYPapas());

      final r = await repo.rellenar(_negocio);

      expect(r.actualizados, 4);
      expect(r.yaCompletos, 0);
      expect(r.total, 4);
      final gaseosa = await leer('gaseosa');
      expect(gaseosa['nombreBusqueda'], 'pina dulce');
      expect(gaseosa['tipoCaja'], 'simple');
      expect(gaseosa['vendidos'], 0);
      expect((await leer('queso'))['tipoCaja'], 'medida');
      expect((await leer('polo'))['tipoCaja'], 'variable');
      expect((await leer('combo'))['tipoCaja'], 'combo');
    });

    test('no cambia el resto del producto (precio, stock, foto…)', () async {
      await guardarViejo(productoSimple(stock: 24, precioCentavos: 450));
      final antes = await leer('gaseosa');

      await repo.rellenar(_negocio);

      final despues = await leer('gaseosa');
      for (final campo in antes.keys) {
        expect(despues[campo], antes[campo], reason: campo);
      }
    });

    test('un producto completo NO se toca: conserva sus ventas', () async {
      await productos().doc('gaseosa').set({
        ...ProductoFirestoreMapper.paraFirestore(productoSimple()),
        'negocioId': _negocio,
        'vendidos': 7,
      });
      await guardarViejo(quesoPorMedida());

      final r = await repo.rellenar(_negocio);

      expect(r.yaCompletos, 1);
      expect(r.actualizados, 1);
      expect((await leer('gaseosa'))['vendidos'], 7);
    });

    test('a uno que solo le falta vendidos solo se le pone vendidos', () async {
      await productos().doc('gaseosa').set({
        ...ProductoFirestoreMapper.paraFirestore(
          productoSimple(nombre: 'Gaseosa'),
        ),
        'negocioId': _negocio,
      });

      await repo.rellenar(_negocio);

      final d = await leer('gaseosa');
      expect(d['vendidos'], 0);
      expect(d['nombreBusqueda'], 'gaseosa');
    });

    test('es seguro repetirlo: la segunda vez no escribe nada', () async {
      await guardarViejo(productoSimple());
      await repo.rellenar(_negocio);

      final r = await repo.rellenar(_negocio);

      expect(r.actualizados, 0);
      expect(r.yaCompletos, 1);
    });

    test(
      'un negocio sin productos queda listo sin escribir productos',
      () async {
        final r = await repo.rellenar(_negocio);

        expect(r.total, 0);
        expect(r.actualizados, 0);
        expect(await repo.catalogoListo(_negocio), isTrue);
      },
    );

    test('un documento que no es un producto se omite y se cuenta', () async {
      await guardarViejo(productoSimple());
      await productos().doc('basura').set({'cualquier': 'cosa'});

      final r = await repo.rellenar(_negocio);

      expect(r.omitidos, 1);
      expect(r.actualizados, 1);
      expect((await leer('basura')).containsKey('vendidos'), isFalse);
    });

    test('no toca los productos de otro negocio', () async {
      await negocio('otro').set({'propietarioUid': 'x', 'webActiva': false});
      await guardarViejo(productoSimple(), negocioId: 'otro');

      await repo.rellenar(_negocio);

      final ajeno = (await productos('otro').doc('gaseosa').get()).data()!;
      expect(ajeno.containsKey('vendidos'), isFalse);
      expect(await repo.catalogoListo('otro'), isFalse);
    });

    test('más de 500 productos: no escribe NADA ni pone la marca', () async {
      for (var i = 0; i <= RellenoCatalogoCaja.maximoProductos; i++) {
        await guardarViejo(productoSimple(id: 'p$i', nombre: 'P$i'));
      }

      final r = await repo.rellenar(_negocio);

      expect(r.demasiados, isTrue);
      expect(r.actualizados, 0);
      expect((await leer('p0')).containsKey('vendidos'), isFalse);
      expect(await repo.catalogoListo(_negocio), isFalse);
    });

    test('justo 500 productos sí se rellenan', () async {
      for (var i = 0; i < RellenoCatalogoCaja.maximoProductos; i++) {
        await guardarViejo(productoSimple(id: 'p$i', nombre: 'P$i'));
      }

      final r = await repo.rellenar(_negocio);

      expect(r.demasiados, isFalse);
      expect(r.actualizados, 500);
      expect((await leer('p499'))['vendidos'], 0);
    });
  });

  test('sin negocioId no opera', () {
    expect(() => repo.rellenar(' '), throwsStateError);
    expect(() => repo.catalogoListo(' '), throwsStateError);
  });

  group('caso de uso: nada se escribe sin el «sí» de la pantalla', () {
    test('preguntar si hace falta NO escribe nada', () async {
      await guardarViejo(productoSimple());
      final caso = PrepararCatalogoCaja(repo);

      expect(await caso.hacePrecisoPreparar(_negocio), isTrue);

      expect((await leer('gaseosa')).containsKey('vendidos'), isFalse);
      expect(await repo.catalogoListo(_negocio), isFalse);
    });

    test('después de preparar ya no hace falta', () async {
      await guardarViejo(productoSimple());
      final caso = PrepararCatalogoCaja(repo);

      final r = await caso.preparar(_negocio);

      expect(r.actualizados, 1);
      expect(await caso.hacePrecisoPreparar(_negocio), isFalse);
    });
  });

  group('camposFaltantes (puro)', () {
    final producto = productoSimple(nombre: 'Arroz');

    test('un producto completo no necesita nada', () {
      expect(
        RellenoCatalogoCaja.camposFaltantes({
          'nombreBusqueda': 'arroz',
          'tipoCaja': 'simple',
          'vendidos': 3,
        }, producto),
        isEmpty,
      );
    });

    test('un producto viejo necesita los tres', () {
      expect(RellenoCatalogoCaja.camposFaltantes({}, producto), {
        'nombreBusqueda': 'arroz',
        'tipoCaja': 'simple',
        'vendidos': 0,
      });
    });

    test('un tipoCaja raro o un vendidos que no es entero se corrigen', () {
      expect(
        RellenoCatalogoCaja.camposFaltantes({
          'nombreBusqueda': 'arroz',
          'tipoCaja': 'otra-cosa',
          'vendidos': 'muchos',
        }, producto),
        {'tipoCaja': 'simple', 'vendidos': 0},
      );
    });
  });
}
