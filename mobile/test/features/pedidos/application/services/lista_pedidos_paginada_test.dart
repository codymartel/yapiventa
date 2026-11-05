import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/lista_pedidos_paginada.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';

import '../../helpers/pedidos_de_prueba.dart';

void main() {
  final p1 = pedidoDe(const [], id: 'p1', fecha: DateTime.utc(2026, 11, 5, 10));
  final p2 = pedidoDe(const [], id: 'p2', fecha: DateTime.utc(2026, 11, 5, 11));
  final p3 = pedidoDe(const [], id: 'p3', fecha: DateTime.utc(2026, 11, 5, 12));
  final sinFecha = pedidoDe(const [], id: 'nuevo');

  group('ListaPedidosPaginada', () {
    test('vacía: sin pedidos, sin más y sin último', () {
      final lista = ListaPedidosPaginada();

      expect(lista.pedidos, isEmpty);
      expect(lista.hayMas, isFalse);
      expect(lista.ultimoConFecha, isNull);
      expect(lista.etiquetaConteo, '0');
    });

    test('la cabeza en vivo va del más nuevo al más viejo', () {
      final lista = ListaPedidosPaginada().conCabeza([p1, p3, p2]);

      expect(lista.pedidos.map((p) => p.id), ['p3', 'p2', 'p1']);
    });

    test('un pedido sin fecha (aún escribiéndose) es el más nuevo', () {
      final lista = ListaPedidosPaginada().conCabeza([p2, sinFecha, p3]);

      expect(lista.pedidos.first.id, 'nuevo');
      expect(lista.ultimoConFecha!.id, 'p2');
    });

    test('con la cabeza completa avisa que puede haber más', () {
      final lista = ListaPedidosPaginada(tamano: 2).conCabeza([p3, p2]);

      expect(lista.hayMas, isTrue);
      expect(lista.etiquetaConteo, '2+');
    });

    test('con la cabeza incompleta no hay más', () {
      final lista = ListaPedidosPaginada(tamano: 3).conCabeza([p3, p2]);

      expect(lista.hayMas, isFalse);
      expect(lista.etiquetaConteo, '2');
    });

    test(
      '«Ver más» agrega los viejos al final y manda lo que dijo la página',
      () {
        final lista = ListaPedidosPaginada(
          tamano: 2,
        ).conCabeza([p3, p2]).conPagina([p1], hayMas: false);

        expect(lista.pedidos.map((p) => p.id), ['p3', 'p2', 'p1']);
        expect(lista.hayMas, isFalse);
        expect(lista.ultimoConFecha!.id, 'p1');
      },
    );

    test('no repite un pedido que ya está en la cabeza en vivo', () {
      final fresco = pedidoDe(
        const [],
        id: 'p2',
        fecha: DateTime.utc(2026, 11, 5, 11),
        pago: EstadoPago.pagado,
      );
      final lista = ListaPedidosPaginada(
        tamano: 2,
      ).conCabeza([p3, p2]).conPagina([p2, p1], hayMas: true);

      final conCabezaNueva = lista.conCabeza([p3, fresco]);

      expect(conCabezaNueva.pedidos.map((p) => p.id), ['p3', 'p2', 'p1']);
      expect(conCabezaNueva.pedidos[1], same(fresco));
    });

    test(
      'cuando uno sale de la cabeza, el siguiente cargado queda en su lugar',
      () {
        final lista = ListaPedidosPaginada(
          tamano: 2,
        ).conCabeza([p3, p2]).conPagina([p1], hayMas: false);

        final sinP3 = lista.conCabeza([p2, p1]);

        expect(sinP3.pedidos.map((p) => p.id), ['p2', 'p1']);
      },
    );

    test('quitar un pedido viejo no toca la cabeza ni los demás', () {
      final lista = ListaPedidosPaginada(
        tamano: 2,
      ).conCabeza([p3, p2]).conPagina([p1], hayMas: true);

      final sin = lista.sinPedidoViejo('p1');

      expect(sin.pedidos.map((p) => p.id), ['p3', 'p2']);
      expect(sin.hayMas, isTrue);
      expect(lista.sinPedidoViejo('p3'), same(lista));
    });

    test('sin páginas deja solo la cabeza y vuelve a juzgar «hay más»', () {
      final lista = ListaPedidosPaginada(
        tamano: 2,
      ).conCabeza([p3, p2]).conPagina([p1], hayMas: false);

      final reiniciada = lista.sinPaginas();

      expect(reiniciada.pedidos.map((p) => p.id), ['p3', 'p2']);
      expect(reiniciada.hayMas, isTrue);
    });

    test('es inmutable: cada cambio devuelve otra lista', () {
      final base = ListaPedidosPaginada().conCabeza([p1]);
      final otra = base.conCabeza([p2]);

      expect(base.pedidos.single.id, 'p1');
      expect(otra.pedidos.single.id, 'p2');
    });
  });
}
