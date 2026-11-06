import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/use_cases/avanzar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_vencidos.dart';
import 'package:mobile/features/pedidos/application/use_cases/confirmar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/marcar_pago_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/marcar_reembolso_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/filtro_pedidos.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/presentation/providers/pedidos_provider.dart';

import '../../helpers/repositorio_pedidos_fake.dart';

final _ahora = DateTime.utc(2026, 11, 5, 20);

Pedido _p(
  String id, {
  EstadoPedido estado = EstadoPedido.nuevo,
  EstadoPago pago = EstadoPago.pendiente,
  int total = 1000,
  List<LineaPedido> lineas = const [],
}) {
  return Pedido(
    id: id,
    clave: 'K$id',
    estado: estado,
    estadoPago: pago,
    fecha: _ahora.subtract(const Duration(minutes: 5)),
    totalCentavos: total,
    lineas: lineas,
  );
}

void main() {
  late RepositorioPedidosFake repo;
  late PedidosProvider provider;

  setUp(() {
    repo = RepositorioPedidosFake();
    provider = PedidosProvider(
      negocioId: 'n1',
      repositorio: repo,
      confirmarPedido: ConfirmarPedido(repo),
      cancelarPedido: CancelarPedido(repo),
      avanzarPedido: AvanzarPedido(repo),
      marcarPagoPedido: MarcarPagoPedido(repo),
      marcarReembolsoPedido: MarcarReembolsoPedido(repo),
      cancelarVencidos: CancelarVencidos(repo),
      reloj: () => _ahora,
    );
  });

  tearDown(() => provider.dispose());

  Future<void> pasar() => Future<void>.delayed(Duration.zero);

  group('pestañas que se escuchan solo mientras se ven', () {
    test('al abrir solo se escuchan Nuevos y Activos', () async {
      provider.iniciar();
      await pasar();

      expect(repo.oyentesActivos, 2);
      expect(repo.oyentesDe(FiltroPedidos.nuevos), 1);
      expect(repo.oyentesDe(FiltroPedidos.activos), 1);
      expect(repo.oyentesDe(FiltroPedidos.porCobrar), 0);
    });

    test(
      'abrir Por cobrar abre su consulta y volver a Nuevos la cierra',
      () async {
        provider.iniciar();
        await pasar();

        provider.seleccionarPestana(PestanaPedidos.porCobrar);
        await pasar();
        expect(repo.oyentesDe(FiltroPedidos.porCobrar), 1);
        expect(repo.oyentesActivos, 3);

        provider.seleccionarPestana(PestanaPedidos.nuevos);
        await pasar();
        expect(repo.oyentesDe(FiltroPedidos.porCobrar), 0);
        expect(repo.oyentesActivos, 2);
      },
    );

    test(
      'pasar de una pestaña a otra deja abierta solo la que se ve',
      () async {
        provider.iniciar();
        provider.seleccionarPestana(PestanaPedidos.porCobrar);
        await pasar();

        provider.seleccionarPestana(PestanaPedidos.reembolsos);
        await pasar();

        expect(repo.oyentesDe(FiltroPedidos.porCobrar), 0);
        expect(repo.oyentesDe(FiltroPedidos.reembolsos), 1);
        expect(repo.oyentesDe(FiltroPedidos.nuevos), 1);
      },
    );

    test('cambiar de pestaña no reabre el resumen del día', () async {
      provider.iniciar();
      await pasar();

      provider.seleccionarPestana(PestanaPedidos.todos);
      provider.seleccionarPestana(PestanaPedidos.reembolsos);
      provider.seleccionarPestana(PestanaPedidos.nuevos);
      await pasar();

      expect(repo.escuchasResumen, hasLength(1));
    });

    test('el número de la pestaña solo aparece cuando ya se abrió', () async {
      provider.iniciar();
      await pasar();
      expect(provider.conteoDisponible(PestanaPedidos.nuevos), isTrue);
      expect(provider.conteoDisponible(PestanaPedidos.porCobrar), isFalse);

      provider.seleccionarPestana(PestanaPedidos.porCobrar);
      repo.emitir(FiltroPedidos.porCobrar, [_p('a'), _p('b')]);
      await pasar();

      expect(provider.conteoDisponible(PestanaPedidos.porCobrar), isTrue);
      expect(provider.conteo(PestanaPedidos.porCobrar), '2');
      // Al dejarla, el número ya cargado se conserva.
      provider.seleccionarPestana(PestanaPedidos.nuevos);
      expect(provider.conteoDisponible(PestanaPedidos.porCobrar), isTrue);
    });

    test('muestra lo de la pestaña elegida', () async {
      provider.iniciar();
      provider.seleccionarPestana(PestanaPedidos.reembolsos);
      repo.emitir(FiltroPedidos.reembolsos, [
        _p('r', estado: EstadoPedido.cancelado, pago: EstadoPago.pagado),
      ]);
      await pasar();

      expect(provider.pedidosActuales.single.id, 'r');
      expect(provider.buscar('r'), isNotNull);
    });

    test('pausar cierra todo y reanudar reabre lo que se ve', () async {
      provider.iniciar();
      provider.seleccionarPestana(PestanaPedidos.porCobrar);
      await pasar();

      provider.pausar();
      await pasar();
      expect(repo.oyentesActivos, 0);

      provider.reanudar();
      await pasar();
      expect(repo.oyentesDe(FiltroPedidos.porCobrar), 1);
      expect(repo.oyentesDe(FiltroPedidos.nuevos), 1);
    });

    test('«por preparar» no cuenta dos veces lo que sale en Todos', () async {
      const linea = LineaPedido(
        productoId: 'inca',
        nombre: 'Inca',
        cantidad: 2,
        precioCentavos: 100,
      );
      provider.iniciar();
      provider.seleccionarPestana(PestanaPedidos.todos);
      repo.emitir(FiltroPedidos.nuevos, [
        _p('a', lineas: [linea]),
      ]);
      repo.emitir(FiltroPedidos.activos, const []);
      repo.emitir(FiltroPedidos.todos, [
        _p('a', lineas: [linea]),
      ]);
      await pasar();

      expect(provider.porPreparar.single.cantidad, 2);
    });
  });

  group('por cobrar de todo el negocio', () {
    test('usa la suma de la consulta, no solo lo cargado', () async {
      repo.sumaPorCobrar = 56400;
      provider.iniciar();
      repo.emitir(FiltroPedidos.nuevos, [_p('a', total: 1840)]);
      repo.emitir(FiltroPedidos.activos, const []);
      await pasar();

      expect(provider.porCobrarEsExacto, isTrue);
      expect(provider.porCobrarCentavos, 56400);
      expect(provider.porCobrarCargadoCentavos, 1840);
    });

    test('si la suma falla (falta el índice) usa lo cargado', () async {
      repo.sumaPorCobrar = null;
      provider.iniciar();
      repo.emitir(FiltroPedidos.nuevos, [_p('a', total: 1840)]);
      repo.emitir(FiltroPedidos.activos, const []);
      await pasar();

      expect(provider.porCobrarEsExacto, isFalse);
      expect(provider.porCobrarCentavos, 1840);
    });

    test(
      'al abrir pide la suma una vez y al cobrar un pedido la vuelve a pedir',
      () async {
        provider.iniciar();
        repo.emitir(FiltroPedidos.nuevos, [_p('a')]);
        repo.emitir(FiltroPedidos.activos, const []);
        await pasar();
        expect(repo.sumasPedidas, 1);

        await provider.marcarPago(_p('a'), EstadoPago.pagado);
        await pasar();

        expect(repo.sumasPedidas, 2);
      },
    );

    test('abrir la pestaña Por cobrar la actualiza', () async {
      provider.iniciar();
      await pasar();
      final antes = repo.sumasPedidas;

      provider.seleccionarPestana(PestanaPedidos.porCobrar);
      await pasar();

      expect(repo.sumasPedidas, antes + 1);
    });
  });

  group('reembolsos', () {
    test('marcar el reembolso como hecho llama al caso de uso', () async {
      provider.iniciar();
      provider.seleccionarPestana(PestanaPedidos.reembolsos);
      final pedido = _p(
        'r',
        estado: EstadoPedido.cancelado,
        pago: EstadoPago.pagado,
      );
      repo.emitir(FiltroPedidos.reembolsos, [pedido]);
      await pasar();

      final r = await provider.marcarReembolsoHecho(pedido);

      expect(r.tipo, TipoResultado.exito);
      expect(repo.llamadas, ['reembolso:r']);
    });
  });
}
