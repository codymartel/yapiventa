import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/domain/models/filtro_pedidos.dart';

import '../helpers/banco_pedidos_repo.dart';
import '../helpers/pedidos_de_prueba.dart';

void main() {
  final banco = BancoPedidosRepo();
  setUp(banco.preparar);

  group('escucharPedidos e historial', () {
    test('trae solo los abiertos, del más nuevo al más viejo', () async {
      await banco
          .pedidos()
          .doc('a')
          .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 15)));
      await banco
          .pedidos()
          .doc('b')
          .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 16)));
      await banco.pedidos().doc('c').set(pedidoMapa(estado: 'entregado'));
      await banco
          .pedidos()
          .doc('d')
          .set(
            pedidoMapa(
              estado: 'en_camino',
              fecha: DateTime.utc(2026, 11, 5, 14),
            ),
          );

      final lista = await banco.repo.escucharPedidos(negocioDePrueba).first;

      expect(lista.map((p) => p.id), ['b', 'a', 'd']);
    });

    test('respeta el límite', () async {
      for (var i = 0; i < 5; i++) {
        await banco
            .pedidos()
            .doc('p$i')
            .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 10 + i)));
      }

      final lista = await banco.repo
          .escucharPedidos(negocioDePrueba, limite: 3)
          .first;

      expect(lista, hasLength(3));
    });

    test('por defecto trae solo 10 abiertos', () async {
      for (var i = 0; i < 12; i++) {
        await banco
            .pedidos()
            .doc('p$i')
            .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 1, i)));
      }

      final lista = await banco.repo.escucharPedidos(negocioDePrueba).first;

      expect(lista, hasLength(10));
      expect(lista.first.id, 'p11');
    });

    test(
      'con estado trae solo ese estado, del más nuevo al más viejo',
      () async {
        await banco
            .pedidos()
            .doc('a')
            .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 15)));
        await banco
            .pedidos()
            .doc('b')
            .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 16)));
        await banco.pedidos().doc('c').set(pedidoMapa(estado: 'confirmado'));

        final nuevos = await banco.repo
            .escucharPedidos(negocioDePrueba, filtro: FiltroPedidos.nuevos)
            .first;

        expect(nuevos.map((p) => p.id), ['b', 'a']);
      },
    );

    test('Activos junta confirmado, en camino y listo, sin nuevos', () async {
      await banco.pedidos().doc('n').set(pedidoMapa());
      await banco
          .pedidos()
          .doc('c')
          .set(
            pedidoMapa(
              estado: 'confirmado',
              fecha: DateTime.utc(2026, 11, 5, 14),
            ),
          );
      await banco
          .pedidos()
          .doc('e')
          .set(
            pedidoMapa(
              estado: 'en_camino',
              fecha: DateTime.utc(2026, 11, 5, 15),
            ),
          );
      await banco
          .pedidos()
          .doc('l')
          .set(
            pedidoMapa(estado: 'listo', fecha: DateTime.utc(2026, 11, 5, 13)),
          );
      await banco.pedidos().doc('x').set(pedidoMapa(estado: 'entregado'));

      final activos = await banco.repo
          .escucharPedidos(negocioDePrueba, filtro: FiltroPedidos.activos)
          .first;

      expect(activos.map((p) => p.id), ['e', 'c', 'l']);
    });

    // fake_cloud_firestore 3.1.0 ignora el orden descendente en startAfter
    // (devuelve vacío). Contra el emulador real de Firestore (2026-11-05) la
    // misma consulta devuelve los más viejos, como se espera.
    const fakeSinCursorDescendente =
        'fake_cloud_firestore no soporta startAfter con orden descendente';

    test(
      '«Ver más» trae los 10 siguientes de ese estado',
      skip: fakeSinCursorDescendente,
      () async {
        for (var i = 0; i < 13; i++) {
          await banco
              .pedidos()
              .doc('n$i')
              .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 1, i)));
        }
        await banco
            .pedidos()
            .doc('otro')
            .set(
              pedidoMapa(
                estado: 'confirmado',
                fecha: DateTime.utc(2026, 11, 1),
              ),
            );

        final vistos = await banco.repo
            .escucharPedidos(negocioDePrueba, filtro: FiltroPedidos.nuevos)
            .first;
        final segunda = await banco.repo.obtenerPedidosDespuesDe(
          negocioDePrueba,
          vistos.last,
          filtro: FiltroPedidos.nuevos,
        );

        expect(vistos.map((p) => p.id), [for (var i = 12; i >= 3; i--) 'n$i']);
        expect(segunda.pedidos.map((p) => p.id), ['n2', 'n1', 'n0']);
        expect(segunda.hayMas, isFalse);
      },
    );

    test(
      '«Ver más» dice si todavía hay otra página',
      skip: fakeSinCursorDescendente,
      () async {
        for (var i = 0; i < 5; i++) {
          await banco
              .pedidos()
              .doc('n$i')
              .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 1, i)));
        }
        final cabeza =
            (await banco.repo.escucharPedidos(negocioDePrueba, limite: 1).first)
                .single;

        final pagina = await banco.repo.obtenerPedidosDespuesDe(
          negocioDePrueba,
          cabeza,
          limite: 2,
        );

        expect(pagina.pedidos.map((p) => p.id), ['n3', 'n2']);
        expect(pagina.hayMas, isTrue);
      },
    );

    test('«Ver más» pide un pedido con fecha', () {
      expect(
        () => banco.repo.obtenerPedidosDespuesDe(
          negocioDePrueba,
          pedidoDe(const []),
        ),
        throwsArgumentError,
      );
    });

    test('vencidos: solo los nuevos anteriores al corte', () async {
      await banco
          .pedidos()
          .doc('viejo')
          .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 4, 20)));
      await banco
          .pedidos()
          .doc('mas-viejo')
          .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 4, 10)));
      await banco
          .pedidos()
          .doc('reciente')
          .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 10)));
      await banco
          .pedidos()
          .doc('confirmado')
          .set(
            pedidoMapa(estado: 'confirmado', fecha: DateTime.utc(2026, 11, 4)),
          );

      final lista = await banco.repo.obtenerVencidos(
        negocioDePrueba,
        antesDe: DateTime.utc(2026, 11, 5, 5),
      );

      expect(lista.map((p) => p.id), ['viejo', 'mas-viejo']);
    });

    test('vencidos respeta el límite', () async {
      for (var i = 0; i < 4; i++) {
        await banco
            .pedidos()
            .doc('v$i')
            .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 1, i)));
      }

      final lista = await banco.repo.obtenerVencidos(
        negocioDePrueba,
        antesDe: DateTime.utc(2026, 11, 5),
        limite: 3,
      );

      expect(lista, hasLength(3));
    });

    test('el historial pagina de a poco y dice si hay más', () async {
      for (var i = 0; i < 5; i++) {
        await banco
            .pedidos()
            .doc('h$i')
            .set(
              pedidoMapa(
                estado: i.isEven ? 'entregado' : 'cancelado',
                fecha: DateTime.utc(2026, 11, 1 + i),
              ),
            );
      }
      await banco.pedidos().doc('abierto').set(pedidoMapa());

      final primera = await banco.repo.obtenerHistorial(
        negocioDePrueba,
        limite: 2,
      );
      final segunda = await banco.repo.obtenerHistorial(
        negocioDePrueba,
        limite: 2,
        despuesDe: primera.ultimoCursor,
      );
      final tercera = await banco.repo.obtenerHistorial(
        negocioDePrueba,
        limite: 2,
        despuesDe: segunda.ultimoCursor,
      );

      expect(primera.pedidos.map((p) => p.id), ['h4', 'h3']);
      expect(primera.hayMas, isTrue);
      expect(segunda.pedidos.map((p) => p.id), ['h2', 'h1']);
      expect(tercera.pedidos.map((p) => p.id), ['h0']);
      expect(tercera.hayMas, isFalse);
    });
  });

  group('filtros: todos, por cobrar y reembolsos', () {
    Future<List<String>> ids(FiltroPedidos filtro) async {
      final lista = await banco.repo
          .escucharPedidos(negocioDePrueba, filtro: filtro)
          .first;
      return [for (final p in lista) p.id];
    }

    test(
      'todos: los abiertos mezclados, sin entregados ni cancelados',
      () async {
        await banco
            .pedidos()
            .doc('n')
            .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 10)));
        await banco
            .pedidos()
            .doc('c')
            .set(
              pedidoMapa(
                estado: 'confirmado',
                fecha: DateTime.utc(2026, 11, 5, 11),
              ),
            );
        await banco.pedidos().doc('e').set(pedidoMapa(estado: 'entregado'));
        await banco.pedidos().doc('x').set(pedidoMapa(estado: 'cancelado'));

        expect(await ids(FiltroPedidos.todos), ['c', 'n']);
      },
    );

    test(
      'por cobrar: sin cobrar y no cancelados, con los entregados',
      () async {
        await banco
            .pedidos()
            .doc('nuevo')
            .set(pedidoMapa(fecha: DateTime.utc(2026, 11, 5, 10)));
        await banco
            .pedidos()
            .doc('entregado')
            .set(
              pedidoMapa(
                estado: 'entregado',
                fecha: DateTime.utc(2026, 11, 5, 11),
              ),
            );
        await banco
            .pedidos()
            .doc('pagado')
            .set(pedidoMapa(estadoPago: 'pagado'));
        await banco
            .pedidos()
            .doc('cancelado')
            .set(pedidoMapa(estado: 'cancelado'));

        expect(await ids(FiltroPedidos.porCobrar), ['entregado', 'nuevo']);
      },
    );

    test('reembolsos: solo cancelados con el reembolso pendiente', () async {
      await banco
          .pedidos()
          .doc('r1')
          .set(
            pedidoMapa(
              estado: 'cancelado',
              estadoPago: 'pagado',
              reembolso: 'pendiente',
              fecha: DateTime.utc(2026, 11, 5, 10),
            ),
          );
      await banco
          .pedidos()
          .doc('hecho')
          .set(
            pedidoMapa(
              estado: 'cancelado',
              estadoPago: 'pagado',
              reembolso: 'hecho',
            ),
          );
      await banco.pedidos().doc('sin').set(pedidoMapa(estado: 'cancelado'));
      await banco
          .pedidos()
          .doc('abierto')
          .set(pedidoMapa(reembolso: 'pendiente'));

      expect(await ids(FiltroPedidos.reembolsos), ['r1']);
    });

    test(
      'cancelar uno pagado lo deja en reembolsos y marcarlo hecho lo saca',
      () async {
        await banco.pedidos().doc('p1').set(pedidoMapa(estadoPago: 'pagado'));
        await banco.repo.cancelar(negocioDePrueba, 'p1');
        expect(await ids(FiltroPedidos.reembolsos), ['p1']);

        await banco.repo.marcarReembolsoHecho(negocioDePrueba, 'p1');

        expect(await ids(FiltroPedidos.reembolsos), isEmpty);
      },
    );

    test(
      'la suma de por cobrar es de TODO el negocio, en céntimos enteros',
      () async {
        await banco.pedidos().doc('a').set(pedidoMapa());
        await banco.pedidos().doc('b').set(pedidoMapa(estado: 'entregado'));
        await banco.pedidos().doc('c').set(pedidoMapa(estadoPago: 'pagado'));
        await banco.pedidos().doc('d').set(pedidoMapa(estado: 'cancelado'));

        // a y b: 1 840 + 1 840. El pagado y el cancelado no cuentan.
        expect(await banco.repo.sumarPorCobrar(negocioDePrueba), 3680);
      },
    );

    test('la suma sin pedidos por cobrar es 0', () async {
      expect(await banco.repo.sumarPorCobrar(negocioDePrueba), 0);
    });
  });

  test('sin negocioId no opera', () {
    expect(() => banco.repo.escucharPedidos('  '), throwsStateError);
  });
}
