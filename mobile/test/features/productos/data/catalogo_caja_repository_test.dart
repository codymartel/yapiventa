import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/campos_catalogo_producto.dart';
import 'package:mobile/features/productos/application/use_cases/buscar_productos_caja.dart';
import 'package:mobile/features/productos/data/catalogo_caja_repository.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/data/productos_repository.dart';
import 'package:mobile/features/productos/domain/models/consulta_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

const _negocio = 'n1';

void main() {
  late FakeFirebaseFirestore db;
  late CatalogoCajaRepository repo;

  CollectionReference<Map<String, dynamic>> coleccion() =>
      db.collection('negocios').doc(_negocio).collection('productos');

  /// Guarda un producto como lo deja la app: con sus campos calculados.
  Future<void> guardar(
    Producto p, {
    int? vendidos = 0,
    int dia = 1,
    bool? disponible,
  }) {
    final datos = ProductoFirestoreMapper.paraFirestore(p)
      ..['negocioId'] = _negocio
      ..['fechaCreacion'] = Timestamp.fromDate(DateTime.utc(2026, 11, dia));
    if (vendidos != null) datos['vendidos'] = vendidos;
    if (disponible != null) datos['disponible'] = disponible;
    return coleccion().doc(p.id).set(datos);
  }

  Producto simple(String id, String nombre, {String categoria = ''}) =>
      productoSimple(id: id, nombre: nombre).copyWith(categoria: categoria);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = CatalogoCajaRepository(db);
  });

  Future<List<String>> ids(
    ConsultaCatalogoCaja consulta, {
    int limite = 20,
  }) async {
    final p = await repo.obtenerPagina(_negocio, consulta, limite: limite);
    return p.productos.map((e) => e.id).toList();
  }

  group('de 20 en 20', () {
    test('la primera página trae 20 y avisa que hay más', () async {
      for (var i = 0; i < 25; i++) {
        await guardar(
          simple('p${i.toString().padLeft(2, '0')}', 'Producto $i'),
        );
      }

      final p = await repo.obtenerPagina(
        _negocio,
        const ConsultaCatalogoCaja(orden: OrdenCatalogoCaja.nombre),
      );

      expect(p.productos, hasLength(20));
      expect(p.hayMas, isTrue);
      expect(p.ultimoCursor, isNotNull);
    });

    test('«ver más» trae los 5 que faltan, sin repetir', () async {
      for (var i = 0; i < 25; i++) {
        await guardar(
          simple('p${i.toString().padLeft(2, '0')}', 'Producto $i'),
        );
      }
      const consulta = ConsultaCatalogoCaja(orden: OrdenCatalogoCaja.nombre);
      final primera = await repo.obtenerPagina(_negocio, consulta);

      final segunda = await repo.obtenerPagina(
        _negocio,
        consulta,
        despuesDe: primera.ultimoCursor,
      );

      expect(segunda.productos, hasLength(5));
      expect(segunda.hayMas, isFalse);
      final todos = [...primera.productos, ...segunda.productos];
      expect(todos.map((e) => e.id).toSet(), hasLength(25));
    });

    test('exactamente 20 no avisa que hay más', () async {
      for (var i = 0; i < 20; i++) {
        await guardar(simple('p$i', 'Producto $i'));
      }

      final p = await repo.obtenerPagina(
        _negocio,
        const ConsultaCatalogoCaja(),
      );

      expect(p.productos, hasLength(20));
      expect(p.hayMas, isFalse);
    });

    test('el caso de uso pide siempre 20', () async {
      for (var i = 0; i < 30; i++) {
        await guardar(simple('p$i', 'Producto $i'));
      }

      final p = await BuscarProductosCaja(repo)(negocioId: _negocio);

      expect(p.productos, hasLength(BuscarProductosCaja.tamanoPagina));
    });
  });

  group('qué productos salen', () {
    test('solo los disponibles', () async {
      await guardar(simple('a', 'Arroz'));
      await guardar(simple('b', 'Azúcar'), disponible: false);

      expect(await ids(const ConsultaCatalogoCaja()), ['a']);
    });

    test('no mezcla el catálogo de otro negocio', () async {
      await guardar(simple('a', 'Arroz'));
      await db
          .collection('negocios')
          .doc('otro')
          .collection('productos')
          .doc('x')
          .set({'nombre': 'Ajeno', 'negocioId': 'otro', 'disponible': true});

      expect(await ids(const ConsultaCatalogoCaja()), ['a']);
    });

    test('filtra por tipo', () async {
      await guardar(simple('a', 'Arroz'));
      await guardar(quesoPorMedida());
      await guardar(poloConModelos());

      expect(
        await ids(
          const ConsultaCatalogoCaja(tipo: CamposCatalogoProducto.tipoMedida),
        ),
        ['queso'],
      );
      expect(
        await ids(
          const ConsultaCatalogoCaja(tipo: CamposCatalogoProducto.tipoVariable),
        ),
        ['polo'],
      );
    });

    test('filtra por categoría exacta', () async {
      await guardar(simple('a', 'Arroz', categoria: 'Abarrotes'));
      await guardar(simple('b', 'Cerveza', categoria: 'Licores'));

      expect(await ids(const ConsultaCatalogoCaja(categoria: 'Licores')), [
        'b',
      ]);
    });

    test('tipo y categoría juntos', () async {
      await guardar(simple('a', 'Arroz', categoria: 'Abarrotes'));
      await guardar(quesoPorMedida().copyWith(categoria: 'Abarrotes'));
      await guardar(simple('c', 'Cerveza', categoria: 'Licores'));

      expect(
        await ids(
          const ConsultaCatalogoCaja(
            tipo: CamposCatalogoProducto.tipoSimple,
            categoria: 'Abarrotes',
          ),
        ),
        ['a'],
      );
    });
  });

  group('búsqueda por el inicio del nombre', () {
    setUp(() async {
      await guardar(simple('a', 'Piña dulce'));
      await guardar(simple('b', 'Pilas AA'));
      await guardar(simple('c', 'Arroz pilado'));
      await guardar(simple('d', 'Gaseosa'));
    });

    test('encuentra por el inicio, ignorando mayúsculas y tildes', () async {
      expect(await ids(const ConsultaCatalogoCaja(texto: 'PI')), ['b', 'a']);
      expect(await ids(const ConsultaCatalogoCaja(texto: 'piñ')), ['a']);
    });

    test('no encuentra por una palabra del medio', () async {
      expect(await ids(const ConsultaCatalogoCaja(texto: 'pilado')), isEmpty);
    });

    test('con una sola letra no filtra (se listan todos)', () async {
      expect(await ids(const ConsultaCatalogoCaja(texto: 'p')), hasLength(4));
    });

    test(
      'con texto el resultado va por nombre, aunque se pida otro orden',
      () async {
        final r = await ids(
          const ConsultaCatalogoCaja(
            texto: 'pi',
            orden: OrdenCatalogoCaja.recientes,
          ),
        );

        expect(r, ['b', 'a']);
      },
    );

    test('la búsqueda respeta el filtro de tipo', () async {
      await guardar(quesoPorMedida().copyWith(nombre: 'Pimienta molida'));

      expect(
        await ids(
          const ConsultaCatalogoCaja(
            texto: 'pi',
            tipo: CamposCatalogoProducto.tipoMedida,
          ),
        ),
        ['queso'],
      );
    });
  });

  group('orden', () {
    test('Frecuentes: más ventas primero; a igual, el más reciente', () async {
      await guardar(simple('poco', 'A'), vendidos: 1, dia: 1);
      await guardar(simple('mucho', 'B'), vendidos: 9, dia: 2);
      await guardar(simple('igual-viejo', 'C'), vendidos: 5, dia: 3);
      await guardar(simple('igual-nuevo', 'D'), vendidos: 5, dia: 4);

      expect(await ids(const ConsultaCatalogoCaja()), [
        'mucho',
        'igual-nuevo',
        'igual-viejo',
        'poco',
      ]);
    });

    test('negocio nuevo (todos en 0): los más recientes primero', () async {
      await guardar(simple('viejo', 'A'), dia: 1);
      await guardar(simple('nuevo', 'B'), dia: 5);

      expect(await ids(const ConsultaCatalogoCaja()), ['nuevo', 'viejo']);
    });

    test(
      'Recientes: los últimos creados primero, tengan o no ventas',
      () async {
        await guardar(simple('viejo', 'A'), vendidos: 9, dia: 1);
        await guardar(simple('nuevo', 'B'), vendidos: null, dia: 5);

        expect(
          await ids(
            const ConsultaCatalogoCaja(orden: OrdenCatalogoCaja.recientes),
          ),
          ['nuevo', 'viejo'],
        );
      },
    );

    test('Nombre: de la A a la Z, sin importar tildes ni mayúsculas', () async {
      await guardar(simple('z', 'Zapallo'));
      await guardar(simple('a', 'Árbol de té'));
      await guardar(simple('m', 'maíz'));

      expect(
        await ids(const ConsultaCatalogoCaja(orden: OrdenCatalogoCaja.nombre)),
        ['a', 'm', 'z'],
      );
    });
  });

  group('productos viejos (sin los campos nuevos)', () {
    test('Recientes los muestra (no depende de los campos nuevos)', () async {
      await coleccion().doc('viejo').set({
        'nombre': 'Arroz',
        'negocioId': _negocio,
        'disponible': true,
        'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
      });

      expect(
        await ids(
          const ConsultaCatalogoCaja(orden: OrdenCatalogoCaja.recientes),
        ),
        ['viejo'],
      );
      // En Firestore real, Frecuentes y Nombre los dejan fuera (falta
      // `vendidos` / `nombreBusqueda`): el simulador no lo imita, se comprobó
      // contra el emulador. Por eso hace falta el relleno único.
    });
  });

  group('errores de programación', () {
    test('sin negocioId no lee', () {
      expect(
        () => repo.obtenerPagina(' ', const ConsultaCatalogoCaja()),
        throwsStateError,
      );
    });

    test('un límite fuera de 1 a 50 se rechaza', () {
      for (final limite in [0, 51]) {
        expect(
          () => repo.obtenerPagina(
            _negocio,
            const ConsultaCatalogoCaja(),
            limite: limite,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('crear y editar un producto', () {
    test('crear deja vendidos en 0 y los campos de búsqueda', () async {
      final productos = ProductosRepository(db);

      final creado = await productos.crearProducto(
        _negocio,
        productoSimple(id: '', nombre: 'Piña Dulce'),
      );

      final doc = (await coleccion().doc(creado.id).get()).data()!;
      expect(doc['vendidos'], 0);
      expect(doc['nombreBusqueda'], 'pina dulce');
      expect(doc['tipoCaja'], 'simple');
    });

    test('editar NO reinicia vendidos y sí recalcula la búsqueda', () async {
      final productos = ProductosRepository(db);
      final creado = await productos.crearProducto(
        _negocio,
        productoSimple(id: '', nombre: 'Arroz'),
      );
      await coleccion().doc(creado.id).update({'vendidos': 7});

      await productos.guardarProducto(
        _negocio,
        creado.copyWith(nombre: 'Arroz Extra'),
      );

      final doc = (await coleccion().doc(creado.id).get()).data()!;
      expect(doc['vendidos'], 7);
      expect(doc['nombreBusqueda'], 'arroz extra');
    });
  });
}
