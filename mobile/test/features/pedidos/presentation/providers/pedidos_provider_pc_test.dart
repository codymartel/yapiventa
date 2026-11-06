import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/use_cases/avanzar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_vencidos.dart';
import 'package:mobile/features/pedidos/application/use_cases/confirmar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/marcar_pago_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/marcar_reembolso_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_pedidos.dart';
import 'package:mobile/features/pedidos/presentation/providers/pedidos_provider.dart';

import '../../helpers/repositorio_pedidos_fake.dart';

const _nuevos = {EstadoPedido.nuevo};
const _activos = {
  EstadoPedido.confirmado,
  EstadoPedido.enCamino,
  EstadoPedido.listo,
};
final _ahora = DateTime.utc(2026, 11, 5, 20);

Pedido _p(
  String id, {
  String nombre = 'Cliente',
  String telefono = '',
  EstadoPedido estado = EstadoPedido.nuevo,
  int minutos = 5,
  List<LineaPedido> lineas = const [],
}) {
  return Pedido(
    id: id,
    clave: 'K$id',
    estado: estado,
    fecha: _ahora.subtract(Duration(minutes: minutos)),
    cliente: ClientePedido(nombre: nombre, telefono: telefono),
    totalCentavos: 1000,
    lineas: lineas,
  );
}

LineaPedido _l(String id, int cantidad) => LineaPedido(
  productoId: id,
  nombre: id,
  cantidad: cantidad,
  precioCentavos: 100,
);

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

  Future<void> cargar({
    List<Pedido> nuevos = const [],
    List<Pedido> activos = const [],
  }) async {
    provider.iniciar();
    repo.emitir(_nuevos, nuevos);
    repo.emitir(_activos, activos);
    await Future<void>.delayed(Duration.zero);
  }

  group('indicadores y por preparar', () {
    test('salen de lo cargado, sin leer nada más', () async {
      await cargar(
        nuevos: [
          _p('a', lineas: [_l('inca', 2)]),
          _p('b', minutos: 21),
        ],
        activos: [
          _p('c', estado: EstadoPedido.confirmado, lineas: [_l('inca', 1)]),
          _p('d', estado: EstadoPedido.enCamino, lineas: [_l('inca', 9)]),
        ],
      );

      expect(provider.indicadores.nuevos, 2);
      expect(provider.indicadores.minutosDelNuevoMasViejo, 21);
      expect(provider.indicadores.enCamino, 1);
      expect(provider.porCobrarCargadoCentavos, 4000);
      // El que va en camino ya salió: no se prepara.
      expect(provider.porPreparar.single.cantidad, 3);
    });
  });

  group('búsqueda', () {
    test('filtra la pestaña actual por cliente, clave o teléfono', () async {
      await cargar(
        nuevos: [
          _p('a', nombre: 'Rosa Quispe', telefono: '987 654 321'),
          _p('b', nombre: 'Juan Paredes', telefono: '912 345 678'),
        ],
      );

      provider.actualizarBusqueda('rosa');
      expect(provider.pedidosFiltrados.map((p) => p.id), ['a']);

      provider.actualizarBusqueda('912 345');
      expect(provider.pedidosFiltrados.map((p) => p.id), ['b']);

      provider.actualizarBusqueda('');
      expect(provider.pedidosFiltrados, hasLength(2));
    });

    test('un texto raro no rompe y solo busca entre lo cargado', () async {
      await cargar(nuevos: [_p('a', nombre: 'Rosa')]);

      provider.actualizarBusqueda('<script>"; DROP TABLE');

      expect(provider.pedidosFiltrados, isEmpty);
      expect(repo.llamadas, isEmpty);
    });
  });

  group('selección y confirmar en lote', () {
    test('marcar, desmarcar y marcar los visibles', () async {
      await cargar(
        nuevos: [
          _p('a', nombre: 'Rosa'),
          _p('b', nombre: 'Juan'),
        ],
      );

      provider.alternarSeleccion('a');
      expect(provider.estaSeleccionado('a'), isTrue);
      provider.alternarSeleccion('a');
      expect(provider.estaSeleccionado('a'), isFalse);

      provider.actualizarBusqueda('rosa');
      provider.seleccionarVisibles(true);
      expect(provider.seleccionados, {'a'});

      provider.seleccionarVisibles(false);
      expect(provider.seleccionados, isEmpty);
    });

    test(
      'confirma los seleccionados de uno en uno y limpia la selección',
      () async {
        await cargar(nuevos: [_p('a'), _p('b'), _p('c')]);
        provider.alternarSeleccion('a');
        provider.alternarSeleccion('c');

        final r = await provider.confirmarSeleccionados();

        expect(repo.llamadas, ['confirmar:a', 'confirmar:c']);
        expect(r.mensaje, 'Se confirmaron 2 pedidos.');
        expect(provider.seleccionados, isEmpty);
      },
    );

    test('si uno no alcanza, los demás siguen y se dice el motivo', () async {
      await cargar(nuevos: [_p('a'), _p('b')]);
      provider.alternarSeleccion('a');
      provider.alternarSeleccion('b');
      repo.resultadoConfirmar = const ResultadoConfirmar(
        faltas: [FaltaStock(nombre: 'Inca', pide: 2, hay: 1)],
      );

      final r = await provider.confirmarSeleccionados();

      expect(r.tipo, TipoResultado.aviso);
      expect(r.mensaje, contains('2 no se pudieron confirmar'));
      expect(r.mensaje, contains('Inca (pide 2, hay 1)'));
    });

    test(
      'solo confirma los nuevos: uno activo seleccionado se salta',
      () async {
        await cargar(
          nuevos: [_p('a')],
          activos: [_p('c', estado: EstadoPedido.confirmado)],
        );
        provider.alternarSeleccion('a');
        provider.alternarSeleccion('c');

        await provider.confirmarSeleccionados();

        expect(repo.llamadas, ['confirmar:a']);
      },
    );

    test('sin selección no hace nada', () async {
      await cargar(nuevos: [_p('a')]);

      final r = await provider.confirmarSeleccionados();

      expect(repo.llamadas, isEmpty);
      expect(r.mensaje, 'No había pedidos por confirmar.');
    });
  });
}
