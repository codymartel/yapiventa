import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_pedidos.dart';
import 'package:mobile/features/pedidos/presentation/providers/historial_pedidos_provider.dart';

import '../../helpers/pedidos_de_prueba.dart';
import '../../helpers/repositorio_pedidos_fake.dart';

class _Cursor implements CursorPedidos {}

Pedido _p(
  String id,
  DateTime fecha, {
  EstadoPedido estado = EstadoPedido.entregado,
  int total = 1000,
}) {
  return pedidoDe(
    [lineaSimple()],
    id: id,
    estado: estado,
    fecha: fecha,
    totalCentavos: total,
  );
}

PaginaPedidos _pagina(List<Pedido> pedidos, {required bool hayMas}) {
  return PaginaPedidos(
    pedidos: pedidos,
    ultimoCursor: pedidos.isEmpty ? null : _Cursor(),
    hayMas: hayMas,
  );
}

void main() {
  late RepositorioPedidosFake repo;
  late HistorialPedidosProvider provider;

  setUp(() {
    repo = RepositorioPedidosFake();
    provider = HistorialPedidosProvider(
      negocioId: 'n1',
      repositorio: repo,
      tamanoPagina: 2,
    );
  });

  tearDown(() => provider.dispose());

  test('cargar trae la primera página y la agrupa por día de Lima', () async {
    repo.paginas.add(
      _pagina([
        _p('a', DateTime.utc(2026, 11, 5, 15), total: 2500),
        _p('b', DateTime.utc(2026, 11, 5, 14), estado: EstadoPedido.cancelado),
      ], hayMas: true),
    );

    await provider.cargar();

    expect(provider.cargado, isTrue);
    expect(provider.dias, hasLength(1));
    expect(provider.dias.single.dia, '2026-11-05');
    expect(provider.dias.single.entregadosCentavos, 2500);
    expect(provider.dias.single.nCancelados, 1);
    expect(provider.hayMas, isTrue);
    expect(provider.ultimoDiaPuedeEstarIncompleto, isTrue);
  });

  test('abrirlo otra vez no vuelve a leer', () async {
    repo.paginas.add(
      _pagina([_p('a', DateTime.utc(2026, 11, 5))], hayMas: false),
    );

    await provider.cargar();
    await provider.cargar();

    expect(repo.llamadas, ['historial:inicio']);
  });

  test('«Ver más» agrega desde el cursor y no repite pedidos', () async {
    repo.paginas
      ..add(
        _pagina([
          _p('a', DateTime.utc(2026, 11, 5, 15)),
          _p('b', DateTime.utc(2026, 11, 5, 14)),
        ], hayMas: true),
      )
      ..add(
        _pagina([
          _p('b', DateTime.utc(2026, 11, 5, 14)),
          _p('c', DateTime.utc(2026, 11, 4, 20)),
        ], hayMas: false),
      );
    await provider.cargar();

    await provider.cargarMas();

    expect(repo.llamadas, ['historial:inicio', 'historial:siguiente']);
    expect(provider.totalCargados, 3);
    expect(provider.dias.map((d) => d.dia), ['2026-11-05', '2026-11-04']);
    expect(provider.hayMas, isFalse);
  });

  test('sin más páginas no lee nada', () async {
    repo.paginas.add(
      _pagina([_p('a', DateTime.utc(2026, 11, 5))], hayMas: false),
    );
    await provider.cargar();

    await provider.cargarMas();

    expect(repo.llamadas, ['historial:inicio']);
  });

  test('«Ver más» antes de cargar no hace nada', () async {
    await provider.cargarMas();

    expect(repo.llamadas, isEmpty);
  });

  test(
    'si falla al cargar avisa, sin detalles internos, y se puede reintentar',
    () async {
      repo.fallaAlVerMas = Exception('permission-denied');

      await provider.cargar();

      expect(provider.error, contains('conexión'));
      expect(provider.error, isNot(contains('permission-denied')));
      expect(provider.cargado, isFalse);
      expect(provider.cargando, isFalse);

      repo.fallaAlVerMas = null;
      repo.paginas.add(
        _pagina([_p('a', DateTime.utc(2026, 11, 5))], hayMas: false),
      );
      await provider.cargar();

      expect(provider.error, isNull);
      expect(provider.cargado, isTrue);
    },
  );

  test('si falla «Ver más» deja lo cargado y avisa', () async {
    repo.paginas.add(
      _pagina([_p('a', DateTime.utc(2026, 11, 5))], hayMas: true),
    );
    await provider.cargar();
    repo.fallaAlVerMas = Exception('sin conexión');

    await provider.cargarMas();

    expect(provider.error, isNotNull);
    expect(provider.totalCargados, 1);
    expect(provider.cargandoMas, isFalse);
  });

  test('refrescar vuelve a leer desde el principio', () async {
    repo.paginas
      ..add(_pagina([_p('a', DateTime.utc(2026, 11, 5))], hayMas: false))
      ..add(
        _pagina([
          _p('z', DateTime.utc(2026, 11, 6)),
          _p('a', DateTime.utc(2026, 11, 5)),
        ], hayMas: false),
      );
    await provider.cargar();

    await provider.refrescar();

    expect(provider.totalCargados, 2);
    expect(repo.llamadas, ['historial:inicio', 'historial:inicio']);
  });

  test('un cliente con etiquetas se conserva como texto', () async {
    repo.paginas.add(
      PaginaPedidos(
        pedidos: [
          Pedido(
            id: 'x',
            estado: EstadoPedido.entregado,
            fecha: DateTime.utc(2026, 11, 5),
            cliente: const ClientePedido(
              nombre: '<img src=x onerror=alert(1)>',
            ),
          ),
        ],
        ultimoCursor: _Cursor(),
        hayMas: false,
      ),
    );

    await provider.cargar();

    expect(
      provider.dias.single.pedidos.single.cliente.nombre,
      '<img src=x onerror=alert(1)>',
    );
  });

  test('no notifica después de dispose', () async {
    repo.paginas.add(
      _pagina([_p('a', DateTime.utc(2026, 11, 5))], hayMas: false),
    );
    final futuro = provider.cargar();
    provider.dispose();

    await futuro;

    provider = HistorialPedidosProvider(negocioId: 'n1', repositorio: repo);
  });
}
