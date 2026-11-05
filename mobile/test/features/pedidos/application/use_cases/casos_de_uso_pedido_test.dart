import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/use_cases/avanzar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_vencidos.dart';
import 'package:mobile/features/pedidos/application/use_cases/confirmar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/marcar_pago_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/marcar_reembolso_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_pedidos.dart';

import '../../helpers/pedidos_de_prueba.dart';
import '../../helpers/repositorio_pedidos_fake.dart';

const _negocio = 'n1';

void main() {
  late RepositorioPedidosFake repo;

  setUp(() => repo = RepositorioPedidosFake());

  group('ConfirmarPedido', () {
    test('devuelve el resultado del repositorio, con lo que falta', () async {
      repo.resultadoConfirmar = const ResultadoConfirmar(yaNoEsNuevo: true);

      final r = await ConfirmarPedido(repo)(
        negocioId: _negocio,
        pedidoId: 'p1',
      );

      expect(r.ok, isFalse);
      expect(r.yaNoEsNuevo, isTrue);
      expect(repo.llamadas, ['confirmar:p1']);
    });

    test('rechaza un pedido sin identificador', () {
      expect(
        () => ConfirmarPedido(repo)(negocioId: _negocio, pedidoId: '  '),
        throwsArgumentError,
      );
      expect(repo.llamadas, isEmpty);
    });
  });

  group('CancelarPedido', () {
    test('devuelve cuántas líneas no se pudieron devolver', () async {
      repo.omitidosAlCancelar = 2;

      final omitidos = await CancelarPedido(repo)(
        negocioId: _negocio,
        pedidoId: 'p1',
      );

      expect(omitidos, 2);
      expect(repo.llamadas, ['cancelar:p1:false']);
    });

    test('rechaza un pedido sin identificador', () {
      expect(
        () => CancelarPedido(repo)(negocioId: _negocio, pedidoId: ''),
        throwsArgumentError,
      );
    });
  });

  group('AvanzarPedido', () {
    Future<EstadoPedido> avanzarCon(Pedido pedido, {bool cobrado = false}) =>
        AvanzarPedido(repo)(
          negocioId: _negocio,
          pedido: pedido,
          cobrado: cobrado,
        );

    test('delivery confirmado pasa a en camino', () async {
      final nuevo = await avanzarCon(
        pedidoDe([lineaSimple()], estado: EstadoPedido.confirmado),
      );

      expect(nuevo, EstadoPedido.enCamino);
      expect(repo.estadoAvanzado, EstadoPedido.enCamino);
      expect(repo.pagoAvanzado, isNull);
    });

    test('recojo confirmado pasa a listo', () async {
      final nuevo = await avanzarCon(
        pedidoDe(
          [lineaSimple()],
          estado: EstadoPedido.confirmado,
          entrega: TipoEntrega.recojo,
        ),
      );

      expect(nuevo, EstadoPedido.listo);
    });

    test('en camino y listo pasan a entregado', () async {
      expect(
        await avanzarCon(
          pedidoDe([lineaSimple()], estado: EstadoPedido.enCamino),
        ),
        EstadoPedido.entregado,
      );
      expect(
        await avanzarCon(pedidoDe([lineaSimple()], estado: EstadoPedido.listo)),
        EstadoPedido.entregado,
      );
    });

    test('entregar y cobrar marca el pago en la misma llamada', () async {
      await avanzarCon(
        pedidoDe([lineaSimple()], estado: EstadoPedido.enCamino),
        cobrado: true,
      );

      expect(repo.estadoAvanzado, EstadoPedido.entregado);
      expect(repo.pagoAvanzado, EstadoPago.pagado);
      expect(repo.llamadas, ['avanzar:ped1']);
    });

    test('un pedido nuevo se confirma con ConfirmarPedido, no aquí', () {
      expect(() => avanzarCon(pedidoDe([lineaSimple()])), throwsArgumentError);
      expect(repo.llamadas, isEmpty);
    });

    test('un entregado o cancelado no tiene paso siguiente', () {
      expect(
        () => avanzarCon(
          pedidoDe([lineaSimple()], estado: EstadoPedido.entregado),
        ),
        throwsStateError,
      );
      expect(
        () => avanzarCon(
          pedidoDe([lineaSimple()], estado: EstadoPedido.cancelado),
        ),
        throwsStateError,
      );
    });

    test('cobrado solo vale al entregar', () {
      expect(
        () => avanzarCon(
          pedidoDe([lineaSimple()], estado: EstadoPedido.confirmado),
          cobrado: true,
        ),
        throwsArgumentError,
      );
      expect(repo.llamadas, isEmpty);
    });
  });

  group('MarcarPagoPedido y MarcarReembolsoPedido', () {
    test('marcan el pago pedido', () async {
      await MarcarPagoPedido(repo)(
        negocioId: _negocio,
        pedidoId: 'p1',
        pago: EstadoPago.pagado,
      );

      expect(repo.llamadas, ['pago:p1:pagado']);
    });

    test('marcan el reembolso como hecho', () async {
      await MarcarReembolsoPedido(repo)(negocioId: _negocio, pedidoId: 'p1');

      expect(repo.llamadas, ['reembolso:p1']);
    });

    test('rechazan un pedido sin identificador', () {
      expect(
        () => MarcarPagoPedido(repo)(
          negocioId: _negocio,
          pedidoId: '',
          pago: EstadoPago.pagado,
        ),
        throwsArgumentError,
      );
      expect(
        () => MarcarReembolsoPedido(repo)(negocioId: _negocio, pedidoId: ' '),
        throwsArgumentError,
      );
    });
  });

  group('CancelarVencidos', () {
    final ahora = DateTime.utc(2026, 11, 5, 20);

    Future<ResultadoCancelarVencidos> cancelar({int limite = 10}) =>
        CancelarVencidos(repo)(
          negocioId: _negocio,
          ahora: ahora,
          limite: limite,
        );

    test('el corte es 12 horas antes de ahora', () async {
      await cancelar();

      expect(repo.corteVencidos, DateTime.utc(2026, 11, 5, 8));
    });

    test('cancela cada vencido solo si sigue nuevo', () async {
      repo.tandasVencidos.add([
        pedidoDe([lineaSimple()], id: 'a'),
        pedidoDe([lineaSimple()], id: 'b'),
      ]);

      final r = await cancelar();

      expect(r.canceladas, 2);
      expect(r.omitidas, 0);
      expect(r.fallidas, 0);
      expect(repo.llamadas, ['cancelar:a:true', 'cancelar:b:true']);
    });

    test('sin vencidos no cancela nada', () async {
      final r = await cancelar();

      expect(r.canceladas, 0);
      expect(r.hayMas, isFalse);
      expect(repo.llamadas, isEmpty);
    });

    test('uno ya confirmado se omite y sigue con el resto', () async {
      repo.tandasVencidos.add([
        pedidoDe([lineaSimple()], id: 'a'),
        pedidoDe([lineaSimple()], id: 'b'),
        pedidoDe([lineaSimple()], id: 'c'),
      ]);
      repo.falloAlCancelar['b'] = StateError('ya no está nuevo');

      final r = await cancelar();

      expect(r.canceladas, 2);
      expect(r.omitidas, 1);
      expect(repo.llamadas, hasLength(3));
    });

    test('un fallo de otra causa se cuenta y no detiene a los demás', () async {
      repo.tandasVencidos.add([
        pedidoDe([lineaSimple()], id: 'a'),
        pedidoDe([lineaSimple()], id: 'b'),
      ]);
      repo.falloAlCancelar['a'] = Exception('sin conexión');

      final r = await cancelar();

      expect(r.fallidas, 1);
      expect(r.canceladas, 1);
      expect(r.omitidas, 0);
    });

    test('una tanda completa avisa que puede haber más', () async {
      repo.tandasVencidos.add([
        pedidoDe([lineaSimple()], id: 'a'),
        pedidoDe([lineaSimple()], id: 'b'),
      ]);

      final r = await cancelar(limite: 2);

      expect(r.hayMas, isTrue);
    });
  });
}
