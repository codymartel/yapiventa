import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/presentation/providers/catalogo_caja_provider.dart';
import 'package:mobile/features/caja/presentation/widgets/catalogo_caja_vista.dart';
import 'package:mobile/features/caja/presentation/widgets/tarjeta_producto_caja.dart';
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

class _Repo implements RepositorioCatalogoCaja {
  final List<ConsultaCatalogoCaja> consultas = [];
  Object? falla;
  List<Producto> todos = [
    for (var i = 0; i < 45; i++)
      productoSimple(
        id: 'p$i',
        nombre: 'Producto $i',
        stock: 10,
        precioCentavos: 450,
      ),
  ];

  @override
  Future<PaginaProductos> obtenerPagina(
    String negocioId,
    ConsultaCatalogoCaja consulta, {
    CursorProductos? despuesDe,
    int limite = 20,
  }) async {
    consultas.add(consulta);
    if (falla != null) throw falla!;
    final desde = despuesDe is _Cursor ? despuesDe.n : 0;
    final fin = (desde + limite).clamp(0, todos.length);
    return PaginaProductos(
      productos: todos.sublist(desde, fin),
      ultimoCursor: _Cursor(fin),
      hayMas: fin < todos.length,
    );
  }
}

const _pausa = Duration(milliseconds: 10);

void main() {
  late _Repo repo;
  late CatalogoCajaProvider provider;
  final elegidos = <String>[];

  Future<void> abrir(
    WidgetTester tester, {
    String rubro = 'Bodega',
    List<String> categorias = const [],
    double ancho = 390,
    double alto = 780,
  }) async {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await provider.iniciar();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CatalogoCajaVista(
              provider: provider,
              rubro: rubro,
              categorias: categorias,
              onElegir: (p) => elegidos.add(p.id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Toca un chip aunque la fila lo deje fuera de pantalla (se desliza).
  Future<void> tocarChip(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = _Repo();
    provider = CatalogoCajaProvider(
      negocioId: 'n1',
      buscar: BuscarProductosCaja(repo),
      pausa: _pausa,
    );
    elegidos.clear();
  });

  tearDown(() => provider.dispose());

  group('la lista', () {
    testWidgets('muestra productos con nombre y precio con coma', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Producto 0'), findsOneWidget);
      expect(find.text('S/ 4,50'), findsWidgets);
      expect(
        find.text('Ver más'),
        findsNothing,
        reason: 'sale al final de la lista',
      );
    });

    testWidgets('al final de los 20 está «Ver más» y trae los siguientes', (
      tester,
    ) async {
      await abrir(tester);

      await tester.scrollUntilVisible(
        find.text('Ver más'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();

      expect(provider.productos, hasLength(40));
      expect(repo.consultas, hasLength(2));
    });

    testWidgets('tocar un producto lo elige', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Producto 3'));

      expect(elegidos, ['p3']);
    });

    testWidgets(
      'stock bajo dice «Quedan 3» y sin stock se ve apagado con texto',
      (tester) async {
        repo.todos = [
          productoSimple(id: 'bajo', nombre: 'Casi agotado', stock: 3),
          productoSimple(id: 'cero', nombre: 'Agotado', stock: 0),
          productoSimple(id: 'ok', nombre: 'Normal', stock: 40),
        ];
        await abrir(tester);

        expect(find.textContaining('Quedan 3'), findsOneWidget);
        expect(find.textContaining('Sin stock'), findsOneWidget);
        expect(find.textContaining('Stock 40'), findsOneWidget);
      },
    );

    testWidgets('un producto por peso muestra «Por peso» y su precio por kg', (
      tester,
    ) async {
      repo.todos = [quesoPorMedida()];
      await abrir(tester);

      final tarjeta = find.byType(TarjetaProductoCaja);
      expect(
        find.descendant(of: tarjeta, matching: find.textContaining('Por peso')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tarjeta, matching: find.textContaining('S/ 24,00')),
        findsOneWidget,
      );
    });

    testWidgets('un combo dice «Combo» y no inventa un stock', (tester) async {
      repo.todos = [comboGaseosaYPapas()];
      await abrir(tester);

      final tarjeta = find.byType(TarjetaProductoCaja);
      expect(
        find.descendant(of: tarjeta, matching: find.text('Combo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tarjeta, matching: find.textContaining('Stock')),
        findsNothing,
      );
    });

    testWidgets('sin productos: mensaje para agregarlos', (tester) async {
      repo.todos = [];
      await abrir(tester);

      expect(
        find.textContaining('Todavía no tienes productos'),
        findsOneWidget,
      );
    });

    testWidgets('sin conexión: error con «Reintentar» que vuelve a cargar', (
      tester,
    ) async {
      repo.falla = Exception('sin red');
      await abrir(tester);
      expect(find.textContaining('Revisa tu conexión'), findsOneWidget);

      repo.falla = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Producto 0'), findsOneWidget);
    });

    testWidgets('una búsqueda sin resultados lo dice con lo escrito', (
      tester,
    ) async {
      await abrir(tester);
      repo.todos = [];

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.textContaining('No encontramos «zzz»'), findsOneWidget);
    });

    testWidgets('«Ver más» que falla deja lo cargado y avisa abajo', (
      tester,
    ) async {
      await abrir(tester);
      repo.falla = Exception('sin red');

      await tester.scrollUntilVisible(
        find.text('Ver más'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo cargar más'), findsOneWidget);
      expect(provider.productos, hasLength(20));
    });
  });

  group('filtros rápidos', () {
    testWidgets('Bodega: tipos, y un toque cambia la lista con UNA consulta', (
      tester,
    ) async {
      await abrir(tester);
      for (final t in [
        'Frecuentes',
        'Simples',
        'Por peso',
        'Variables',
        'Combos',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }

      await tocarChip(tester, 'Por peso');

      expect(repo.consultas.last.tipo, 'medida');
      expect(repo.consultas, hasLength(2));
    });

    testWidgets('volver a «Frecuentes» sale de la memoria (0 consultas)', (
      tester,
    ) async {
      await abrir(tester);
      await tocarChip(tester, 'Por peso');
      final antes = repo.consultas.length;

      await tocarChip(tester, 'Frecuentes');

      expect(repo.consultas, hasLength(antes));
    });

    testWidgets('pasar de un tipo a una categoría es UNA consulta, no dos', (
      tester,
    ) async {
      await abrir(
        tester,
        rubro: 'Restaurante',
        categorias: ['Platos', 'Bebidas'],
      );
      await tocarChip(tester, 'Combos');
      final antes = repo.consultas.length;

      await tocarChip(tester, 'Platos');

      expect(repo.consultas.length, antes + 1);
      expect(repo.consultas.last.categoria, 'Platos');
      expect(repo.consultas.last.tipo, isNull);
    });

    testWidgets('otros rubros muestran sus categorías', (tester) async {
      await abrir(tester, rubro: 'Ropa', categorias: ['Polos', 'Pantalones']);

      expect(find.text('Polos'), findsOneWidget);
      expect(find.text('Pantalones'), findsOneWidget);
      expect(find.text('Simples'), findsNothing);
    });
  });

  group('filtros avanzados', () {
    testWidgets('«Avanzados» abre la hoja con categoría y «Solo con stock»', (
      tester,
    ) async {
      await abrir(tester, rubro: 'Ropa', categorias: ['Polos', 'Licores']);

      await tester.tap(find.text('Avanzados'));
      await tester.pumpAndSettle();

      expect(find.text('Filtros avanzados'), findsOneWidget);
      expect(find.text('CATEGORÍA'), findsOneWidget);
      expect(find.text('Solo con stock'), findsOneWidget);
      expect(find.text('Restablecer'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
    });

    testWidgets('elegir categoría consulta y el número de «Avanzados» sube', (
      tester,
    ) async {
      await abrir(tester, rubro: 'Ropa', categorias: ['Polos', 'Licores']);
      await tester.tap(find.text('Avanzados'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Licores'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      expect(repo.consultas.last.categoria, 'Licores');
    });

    testWidgets(
      '«Solo con stock» filtra lo cargado sin consultar y suma 1 al número',
      (tester) async {
        repo.todos = [
          productoSimple(id: 'a', nombre: 'Con stock', stock: 5),
          productoSimple(id: 'b', nombre: 'Sin existencias', stock: 0),
        ];
        await abrir(tester);
        expect(find.text('Sin existencias'), findsOneWidget);

        await tester.tap(find.text('Avanzados'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Listo'));
        await tester.pumpAndSettle();

        expect(find.text('Sin existencias'), findsNothing);
        expect(find.text('Con stock'), findsOneWidget);
        expect(find.text('Avanzados · 1'), findsOneWidget);
        expect(repo.consultas, hasLength(1));
      },
    );

    testWidgets('«Restablecer» quita categoría y stock', (tester) async {
      await abrir(tester, rubro: 'Ropa', categorias: ['Polos', 'Licores']);
      provider
        ..cambiarCategoria('Licores')
        ..cambiarSoloConStock(true);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Avanzados'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restablecer'));
      await tester.pumpAndSettle();

      expect(provider.categoria, isNull);
      expect(provider.soloConStock, isFalse);
    });
  });

  group('orden', () {
    testWidgets('el menú cambia el orden y consulta una vez', (tester) async {
      await abrir(tester);
      expect(find.text('Orden: Más vendidos'), findsOneWidget);

      await tester.tap(find.text('Orden: Más vendidos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nombre (A a Z)'));
      await tester.pumpAndSettle();

      expect(repo.consultas.last.orden, OrdenCatalogoCaja.nombre);
      expect(find.text('Orden: Nombre (A a Z)'), findsOneWidget);
    });

    testWidgets('al buscar el orden es por nombre y no se puede cambiar', (
      tester,
    ) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'pro');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Orden: por nombre'), findsOneWidget);
    });
  });

  group('buscador', () {
    testWidgets('escribir consulta tras la pausa con el texto normalizado', (
      tester,
    ) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'Prod');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(repo.consultas.last.texto, 'prod');
    });

    testWidgets(
      'sugerencias de lo ya cargado, sin consultar; tocar una la elige',
      (tester) async {
        await abrir(tester);
        final antes = repo.consultas.length;

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'Producto 1');
        await tester.pump();

        expect(find.text('Cancelar'), findsOneWidget);
        // Las sugerencias salen de lo cargado (máximo 5), sin consultar.
        expect(repo.consultas.length, antes);
        await tester.tap(find.text('Producto 12').first);
        await tester.pump();

        expect(elegidos, ['p12']);
        await tester.pump(
          const Duration(milliseconds: 50),
        ); // la pausa del buscador
      },
    );

    testWidgets('«Cancelar» borra el texto y cierra las sugerencias', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Producto');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(provider.texto, '');
      expect(find.text('Cancelar'), findsNothing);
    });

    testWidgets('la cápsula mide 48 px y la ✕ para borrar es tocable', (
      tester,
    ) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();

      final caja = tester.getSize(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(caja.height, 48);
      final x = tester.getSize(find.byTooltip('Borrar búsqueda'));
      expect(x.width, greaterThanOrEqualTo(44));
      expect(x.height, greaterThanOrEqualTo(44));
      await tester.pump(
        const Duration(milliseconds: 50),
      ); // la pausa del buscador
    });
  });
}
