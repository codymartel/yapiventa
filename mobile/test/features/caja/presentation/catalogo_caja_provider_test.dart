import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/presentation/providers/catalogo_caja_provider.dart';
import 'package:mobile/features/productos/application/use_cases/buscar_productos_caja.dart';
import 'package:mobile/features/productos/domain/models/consulta_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_catalogo_caja.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

class _Cursor implements CursorProductos {
  const _Cursor(this.n);
  final int n;
}

/// Un catálogo de 45 productos que responde de 20 en 20 y cuenta las consultas.
class _RepoFalso implements RepositorioCatalogoCaja {
  final List<ConsultaCatalogoCaja> consultas = [];
  Object? falla;
  Duration demora = Duration.zero;
  bool listasFijas = false;
  List<Producto> todos = [
    for (var i = 0; i < 45; i++)
      productoSimple(id: 'p$i', nombre: 'Producto $i', stock: i.isEven ? 5 : 0),
  ];

  @override
  Future<PaginaProductos> obtenerPagina(
    String negocioId,
    ConsultaCatalogoCaja consulta, {
    CursorProductos? despuesDe,
    int limite = 20,
  }) async {
    consultas.add(consulta);
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (falla != null) throw falla!;
    final desde = despuesDe is _Cursor ? despuesDe.n : 0;
    final fin = (desde + limite).clamp(0, todos.length);
    return PaginaProductos(
      productos: listasFijas
          ? List.unmodifiable(todos.sublist(desde, fin))
          : todos.sublist(desde, fin),
      ultimoCursor: _Cursor(fin),
      hayMas: fin < todos.length,
    );
  }
}

const _pausa = Duration(milliseconds: 20);
Future<void> _espera([int ms = 80]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late _RepoFalso repo;
  late CatalogoCajaProvider p;

  setUp(() {
    repo = _RepoFalso();
    p = CatalogoCajaProvider(
      negocioId: 'n1',
      buscar: BuscarProductosCaja(repo),
      pausa: _pausa,
    );
  });

  tearDown(() => p.dispose());

  test('al iniciar trae 20 y avisa que hay más', () async {
    await p.iniciar();

    expect(p.productos, hasLength(20));
    expect(p.hayMas, isTrue);
    expect(p.cargando, isFalse);
    expect(repo.consultas, hasLength(1));
  });

  test('«ver más» suma los 20 siguientes y luego los 5 que faltan', () async {
    await p.iniciar();

    await p.verMas();
    expect(p.productos, hasLength(40));
    await p.verMas();

    expect(p.productos, hasLength(45));
    expect(p.hayMas, isFalse);
    expect(p.productos.map((e) => e.id).toSet(), hasLength(45));
  });

  test(
    '«ver más» funciona aunque el repositorio devuelva una lista fija',
    () async {
      repo.listasFijas = true;
      await p.iniciar();

      await p.verMas();

      expect(p.productos, hasLength(40));
    },
  );

  test('«ver más» sin más páginas no consulta', () async {
    repo.todos = repo.todos.take(5).toList();
    await p.iniciar();

    await p.verMas();

    expect(repo.consultas, hasLength(1));
  });

  group('buscador', () {
    test('espera la pausa y consulta una sola vez por lo escrito', () async {
      await p.iniciar();

      p.escribir('g');
      p.escribir('ga');
      p.escribir('gas');
      await _espera();

      expect(repo.consultas, hasLength(2), reason: 'iniciar + una búsqueda');
      expect(repo.consultas.last.texto, 'gas');
    });

    test('con menos de 2 letras no consulta', () async {
      await p.iniciar();

      p.escribir('g');
      await _espera();

      expect(repo.consultas, hasLength(1));
      expect(p.texto, 'g', reason: 'el campo muestra lo escrito al instante');
    });

    test('normaliza tildes y mayúsculas', () async {
      await p.iniciar();

      p.escribir('  PIÑ ');
      await _espera();

      expect(repo.consultas.last.texto, 'pin');
    });

    test(
      'limpiar el buscador vuelve a la lista de antes sin consultar',
      () async {
        await p.iniciar();
        p.escribir('gas');
        await _espera();
        final antes = repo.consultas.length;

        p.limpiarBusqueda();
        await _espera();

        expect(p.texto, '');
        expect(repo.consultas, hasLength(antes), reason: 'estaba en memoria');
        expect(p.productos, hasLength(20));
      },
    );
  });

  group('memoria de la sesión (ahorro de lecturas)', () {
    test('volver a un filtro ya visto cuesta 0 consultas', () async {
      await p.iniciar();
      p.cambiarTipo('medida');
      await _espera();
      expect(repo.consultas, hasLength(2));

      p.cambiarTipo(null);
      await _espera();

      expect(repo.consultas, hasLength(2));
      expect(p.productos, hasLength(20));
    });

    test('«ver más» queda guardado: al volver no se pide otra vez', () async {
      await p.iniciar();
      await p.verMas();
      p.cambiarCategoria('Licores');
      await _espera();
      final antes = repo.consultas.length;

      p.cambiarCategoria(null);
      await _espera();

      expect(repo.consultas, hasLength(antes));
      expect(p.productos, hasLength(40));
    });

    test('reiniciar olvida la memoria y vuelve a consultar', () async {
      await p.iniciar();

      await p.reiniciar();

      expect(repo.consultas, hasLength(2));
    });

    test('el mismo tipo o el mismo orden no vuelven a consultar', () async {
      await p.iniciar();

      p.cambiarTipo(null);
      p.cambiarOrden(OrdenCatalogoCaja.frecuentes);
      await _espera();

      expect(repo.consultas, hasLength(1));
    });
  });

  group('filtros', () {
    test('tipo, categoría y orden viajan en la consulta', () async {
      await p.iniciar();

      p.cambiarTipo('combo');
      p.cambiarCategoria('Bebidas');
      p.cambiarOrden(OrdenCatalogoCaja.nombre);
      await _espera();

      final c = repo.consultas.last;
      expect(
        [c.tipo, c.categoria, c.orden],
        ['combo', 'Bebidas', OrdenCatalogoCaja.nombre],
      );
    });

    test('«solo con stock» filtra lo cargado y NO consulta', () async {
      await p.iniciar();

      p.cambiarSoloConStock(true);

      expect(repo.consultas, hasLength(1));
      expect(p.productos.every((e) => e.stock > 0), isTrue);
      expect(p.productos.length, lessThan(20));
      p.cambiarSoloConStock(false);
      expect(p.productos, hasLength(20));
    });

    test(
      'buscando, cambiar el orden no consulta (siempre va por nombre)',
      () async {
        await p.iniciar();
        p.escribir('gas');
        await _espera();
        final antes = repo.consultas.length;

        p.cambiarOrden(OrdenCatalogoCaja.recientes);
        await _espera();

        expect(repo.consultas, hasLength(antes));
        expect(p.buscando, isTrue);
      },
    );
  });

  group('estados', () {
    test('sin productos: vacío', () async {
      repo.todos = [];
      await p.iniciar();

      expect(p.vacio, isTrue);
      expect(p.hayMas, isFalse);
    });

    test('sin conexión: error con mensaje, y reintentar funciona', () async {
      repo.falla = Exception('sin red');
      await p.iniciar();

      expect(p.error, contains('conexión'));
      expect(p.productos, isEmpty);

      repo.falla = null;
      await p.reiniciar();
      expect(p.error, isNull);
      expect(p.productos, hasLength(20));
    });

    test('«ver más» que falla conserva lo cargado y avisa', () async {
      await p.iniciar();
      repo.falla = Exception('sin red');

      await p.verMas();

      expect(p.productos, hasLength(20));
      expect(p.error, isNotNull);
      expect(p.cargandoMas, isFalse);
    });

    test('un resultado viejo que llega tarde se descarta', () async {
      repo.demora = const Duration(milliseconds: 60);
      final primera = p.iniciar();
      await _espera(10);
      repo.demora = Duration.zero;
      p.cambiarTipo('medida');

      await primera;
      await _espera(120);

      expect(repo.consultas.last.tipo, 'medida');
      expect(p.tipo, 'medida');
      expect(p.cargando, isFalse);
    });

    test('al cerrarse ya no avisa ni consulta', () async {
      p.escribir('gas');
      p.dispose();
      await _espera();

      expect(repo.consultas, isEmpty);
      // tearDown vuelve a llamar dispose: no debe fallar.
      p = CatalogoCajaProvider(
        negocioId: 'n1',
        buscar: BuscarProductosCaja(repo),
      );
    });
  });
}
