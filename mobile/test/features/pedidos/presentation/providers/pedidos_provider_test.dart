import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/use_cases/avanzar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_vencidos.dart';
import 'package:mobile/features/pedidos/application/use_cases/confirmar_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/marcar_pago_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/marcar_reembolso_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_pedidos.dart';
import 'package:mobile/features/pedidos/presentation/providers/pedidos_provider.dart';

import '../../helpers/pedidos_de_prueba.dart';
import '../../helpers/repositorio_pedidos_fake.dart';

const _nuevos = {EstadoPedido.nuevo};
const _activos = {
  EstadoPedido.confirmado,
  EstadoPedido.enCamino,
  EstadoPedido.listo,
};

Pedido _p(
  String id, {
  int hora = 10,
  EstadoPedido estado = EstadoPedido.nuevo,
  int total = 1840,
}) {
  return pedidoDe(
    [lineaSimple()],
    id: id,
    estado: estado,
    fecha: DateTime.utc(2026, 11, 5, hora),
    totalCentavos: total,
  );
}

void main() {
  late RepositorioPedidosFake repo;
  late PedidosProvider provider;
  var notificaciones = 0;

  PedidosProvider crear({
    int tamano = 10,
    DateTime? ahora,
    DateTime Function()? reloj,
  }) {
    final p = PedidosProvider(
      negocioId: 'n1',
      repositorio: repo,
      confirmarPedido: ConfirmarPedido(repo),
      cancelarPedido: CancelarPedido(repo),
      avanzarPedido: AvanzarPedido(repo),
      marcarPagoPedido: MarcarPagoPedido(repo),
      marcarReembolsoPedido: MarcarReembolsoPedido(repo),
      cancelarVencidos: CancelarVencidos(repo),
      tamanoPagina: tamano,
      reloj: reloj ?? () => ahora ?? DateTime.utc(2026, 11, 5, 20),
    );
    p.addListener(() => notificaciones++);
    return p;
  }

  setUp(() {
    repo = RepositorioPedidosFake();
    notificaciones = 0;
    provider = crear();
  });

  tearDown(() => provider.dispose());

  group('escucha en vivo', () {
    test(
      'iniciar abre solo dos listeners y marca «cargando» hasta recibir',
      () async {
        provider.iniciar();

        expect(repo.escuchas, hasLength(2));
        await Future<void>.delayed(Duration.zero);
        expect(repo.oyentesActivos, 2);
        expect(provider.cargando(PestanaPedidos.nuevos), isTrue);

        repo.emitir(_nuevos, [_p('a')]);
        await Future<void>.delayed(Duration.zero);

        expect(provider.cargando(PestanaPedidos.nuevos), isFalse);
        expect(provider.cargando(PestanaPedidos.activos), isTrue);
        expect(provider.pedidosDe(PestanaPedidos.nuevos).single.id, 'a');
      },
    );

    test('iniciar dos veces no duplica los listeners', () async {
      provider.iniciar();
      provider.iniciar();
      await Future<void>.delayed(Duration.zero);

      expect(repo.escuchas, hasLength(2));
      expect(repo.oyentesActivos, 2);
    });

    test('cada pestaña muestra lo suyo, del más nuevo al más viejo', () async {
      provider.iniciar();
      repo.emitir(_nuevos, [_p('a', hora: 9), _p('b', hora: 11)]);
      repo.emitir(_activos, [_p('c', estado: EstadoPedido.confirmado)]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.pedidosDe(PestanaPedidos.nuevos).map((p) => p.id), [
        'b',
        'a',
      ]);
      provider.seleccionarPestana(PestanaPedidos.activos);
      expect(provider.pedidosActuales.single.id, 'c');
    });

    test(
      'las insignias salen de lo cargado y avisan «10+» si hay más',
      () async {
        provider = crear(tamano: 2);
        provider.iniciar();
        repo.emitir(_nuevos, [_p('a', hora: 9), _p('b', hora: 11)]);
        repo.emitir(_activos, [_p('c', estado: EstadoPedido.confirmado)]);
        await Future<void>.delayed(Duration.zero);

        expect(provider.conteo(PestanaPedidos.nuevos), '2+');
        expect(provider.conteo(PestanaPedidos.activos), '1');
      },
    );

    test('llega un pedido nuevo en vivo y la lista se actualiza', () async {
      provider.iniciar();
      repo.emitir(_nuevos, [_p('a')]);
      await Future<void>.delayed(Duration.zero);
      final antes = notificaciones;

      repo.emitir(_nuevos, [_p('b', hora: 12), _p('a')]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.pedidosDe(PestanaPedidos.nuevos).first.id, 'b');
      expect(notificaciones, greaterThan(antes));
    });

    test(
      'pausar cierra los listeners y conserva lo cargado; reanudar los reabre',
      () async {
        provider.iniciar();
        repo.emitir(_nuevos, [_p('a')]);
        await Future<void>.delayed(Duration.zero);

        provider.pausar();
        await Future<void>.delayed(Duration.zero);

        expect(repo.oyentesActivos, 0);
        expect(provider.pedidosDe(PestanaPedidos.nuevos).single.id, 'a');

        provider.reanudar();
        await Future<void>.delayed(Duration.zero);

        expect(repo.oyentesActivos, 2);
        expect(repo.escuchas, hasLength(4));
        expect(provider.cargando(PestanaPedidos.nuevos), isFalse);
        expect(provider.pedidosDe(PestanaPedidos.nuevos).single.id, 'a');
      },
    );

    test('reanudar sin haber pausado no hace nada', () async {
      provider.iniciar();
      provider.reanudar();

      expect(repo.escuchas, hasLength(2));
    });

    test(
      'un error de conexión se avisa y reintentar vuelve a escuchar',
      () async {
        provider.iniciar();
        await Future<void>.delayed(Duration.zero);

        repo.fallar(_nuevos);
        await Future<void>.delayed(Duration.zero);

        expect(provider.error, contains('conexión'));
        expect(provider.cargando(PestanaPedidos.nuevos), isFalse);

        provider.reintentar();
        await Future<void>.delayed(Duration.zero);
        repo.emitir(_nuevos, [_p('a')]);
        await Future<void>.delayed(Duration.zero);

        expect(provider.error, isNull);
        expect(provider.pedidosDe(PestanaPedidos.nuevos).single.id, 'a');
      },
    );

    test('si abrir la escucha lanza, queda el aviso y no se rompe', () {
      repo.fallaAlEscuchar = StateError('sin negocio');

      provider.iniciar();

      expect(provider.error, isNotNull);
      expect(provider.cargando(PestanaPedidos.nuevos), isFalse);
    });

    test('dispose cierra los listeners y no notifica después', () async {
      provider.iniciar();
      await Future<void>.delayed(Duration.zero);

      provider.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(repo.oyentesActivos, 0);
      // El tearDown vuelve a llamar dispose en otro provider: no debe fallar.
      provider = crear();
    });

    test('un nombre con etiquetas llega tal cual, como texto', () async {
      provider.iniciar();
      const raro = Pedido(
        id: 'x',
        cliente: ClientePedido(nombre: '<script>alert(1)</script>'),
        notas: '"; DROP TABLE pedidos; --',
      );
      repo.emitir(_nuevos, [raro]);
      await Future<void>.delayed(Duration.zero);

      final recibido = provider.pedidosDe(PestanaPedidos.nuevos).single;
      expect(recibido.cliente.nombre, '<script>alert(1)</script>');
      expect(recibido.notas, '"; DROP TABLE pedidos; --');
    });
  });

  group('resumen del día', () {
    test('iniciar escucha UN documento: el de hoy (hora de Lima)', () async {
      provider.iniciar();
      await Future<void>.delayed(Duration.zero);

      expect(repo.escuchasResumen, ['2026-11-05']);
      expect(repo.resumenesActivos, 1);
      expect(provider.resumenHoy.entregados, 0);
    });

    test('lo que llega queda en resumenHoy con su ticket', () async {
      provider.iniciar();
      repo.emitirResumen(
        const ResumenVentasDia(
          dia: '2026-11-05',
          ventasCentavos: 21460,
          entregados: 9,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.resumenHoy.ventasCentavos, 21460);
      expect(provider.resumenHoy.ticketCentavos, 2384);
    });

    test('pausar cierra el resumen y reanudar lo reabre', () async {
      provider.iniciar();
      await Future<void>.delayed(Duration.zero);

      provider.pausar();
      await Future<void>.delayed(Duration.zero);
      expect(repo.resumenesActivos, 0);

      provider.reanudar();
      await Future<void>.delayed(Duration.zero);
      expect(repo.resumenesActivos, 1);
    });

    test('pasada la medianoche pasa a escuchar el día nuevo', () async {
      var ahora = DateTime.utc(2026, 11, 6, 4, 50); // 23:50 del 5 en Lima
      provider = crear(reloj: () => ahora);
      provider.iniciar();
      await Future<void>.delayed(Duration.zero);
      expect(repo.escuchasResumen, ['2026-11-05']);

      provider.revisarDia();
      expect(repo.escuchasResumen, ['2026-11-05'], reason: 'mismo día: nada');

      ahora = DateTime.utc(2026, 11, 6, 5, 10); // 00:10 del 6 en Lima
      provider.revisarDia();
      await Future<void>.delayed(Duration.zero);

      expect(repo.escuchasResumen, ['2026-11-05', '2026-11-06']);
      expect(repo.resumenesActivos, 1);
    });

    test('si el resumen falla, los pedidos siguen sin error', () async {
      repo.fallaAlEscucharResumen = StateError('sin permiso');

      provider.iniciar();
      repo.emitir(_nuevos, [_p('a')]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.error, isNull);
      expect(provider.pedidosDe(PestanaPedidos.nuevos).single.id, 'a');
      expect(provider.resumenHoy.entregados, 0);
    });

    test('dispose cierra el resumen', () async {
      provider.iniciar();
      await Future<void>.delayed(Duration.zero);

      provider.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(repo.resumenesActivos, 0);
      provider = crear();
    });
  });

  group('buscar y por cobrar', () {
    test(
      'busca en cualquier pestaña y suma solo lo pendiente de cobro',
      () async {
        provider.iniciar();
        repo.emitir(_nuevos, [
          _p('a', total: 1840),
          _p('b', hora: 11, total: 1000),
        ]);
        repo.emitir(_activos, [
          pedidoDe(
            [lineaSimple()],
            id: 'c',
            estado: EstadoPedido.confirmado,
            pago: EstadoPago.pagado,
            totalCentavos: 3200,
            fecha: DateTime.utc(2026, 11, 5, 9),
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(provider.buscar('c')!.totalCentavos, 3200);
        expect(provider.buscar('nada'), isNull);
        expect(provider.porCobrarCargadoCentavos, 2840);
      },
    );
  });

  group('Ver más', () {
    Future<void> conCabezaCompleta() async {
      provider = crear(tamano: 2);
      provider.iniciar();
      repo.emitir(_nuevos, [_p('c', hora: 12), _p('b', hora: 11)]);
      await Future<void>.delayed(Duration.zero);
    }

    test('agrega los más viejos desde el último y no repite', () async {
      await conCabezaCompleta();
      repo.paginas.add(
        PaginaPedidos(
          pedidos: [_p('b', hora: 11), _p('a', hora: 10)],
          ultimoCursor: null,
          hayMas: false,
        ),
      );

      final r = await provider.verMas(PestanaPedidos.nuevos);

      expect(r.tipo, TipoResultado.exito);
      expect(repo.despuesDeVerMas, ['b']);
      expect(provider.pedidosDe(PestanaPedidos.nuevos).map((p) => p.id), [
        'c',
        'b',
        'a',
      ]);
      expect(provider.hayMas(PestanaPedidos.nuevos), isFalse);
    });

    test('un segundo toque mientras carga se ignora', () async {
      await conCabezaCompleta();
      repo.esperaVerMas = Completer<void>();
      repo.paginas.add(
        const PaginaPedidos(pedidos: [], ultimoCursor: null, hayMas: false),
      );

      final primera = provider.verMas(PestanaPedidos.nuevos);
      final segunda = await provider.verMas(PestanaPedidos.nuevos);

      expect(provider.cargandoMas(PestanaPedidos.nuevos), isTrue);
      expect(segunda.hizoAlgo, isFalse);
      repo.esperaVerMas!.complete();
      await primera;
      expect(provider.cargandoMas(PestanaPedidos.nuevos), isFalse);
      expect(repo.despuesDeVerMas, hasLength(1));
    });

    test('sin más pedidos no lee nada', () async {
      provider.iniciar();
      repo.emitir(_nuevos, [_p('a')]);
      await Future<void>.delayed(Duration.zero);

      final r = await provider.verMas(PestanaPedidos.nuevos);

      expect(r.hizoAlgo, isFalse);
      expect(repo.despuesDeVerMas, isEmpty);
    });

    test('si falla, avisa y deja la lista como estaba', () async {
      await conCabezaCompleta();
      repo.fallaAlVerMas = Exception('sin conexión');

      final r = await provider.verMas(PestanaPedidos.nuevos);

      expect(r.fallo, isTrue);
      expect(r.mensaje, isNot(contains('Exception')));
      expect(provider.pedidosDe(PestanaPedidos.nuevos), hasLength(2));
      expect(provider.cargandoMas(PestanaPedidos.nuevos), isFalse);
    });

    test('reiniciar páginas descarta lo traído con «Ver más»', () async {
      await conCabezaCompleta();
      repo.paginas.add(
        PaginaPedidos(
          pedidos: [_p('a', hora: 10)],
          ultimoCursor: null,
          hayMas: false,
        ),
      );
      await provider.verMas(PestanaPedidos.nuevos);

      provider.reiniciarPaginas(PestanaPedidos.nuevos);

      expect(provider.pedidosDe(PestanaPedidos.nuevos).map((p) => p.id), [
        'c',
        'b',
      ]);
    });
  });

  group('acciones', () {
    test('confirmar con éxito', () async {
      final r = await provider.confirmar(_p('a'));

      expect(r.tipo, TipoResultado.exito);
      expect(r.mensaje, 'Pedido confirmado.');
      expect(repo.llamadas, ['confirmar:a']);
    });

    test('confirmar sin stock suficiente dice qué falta', () async {
      repo.resultadoConfirmar = const ResultadoConfirmar(
        faltas: [FaltaStock(nombre: 'Gaseosa Inca', pide: 2, hay: 1)],
      );

      final r = await provider.confirmar(_p('a'));

      expect(r.fallo, isTrue);
      expect(r.mensaje, contains('Gaseosa Inca (pide 2, hay 1)'));
    });

    test('confirmar con otro total de hoy avisa pero confirma', () async {
      repo.resultadoConfirmar = const ResultadoConfirmar(
        totalActualCentavos: 1940,
        lineasCambiadas: ['Gaseosa Inca'],
      );

      final r = await provider.confirmar(_p('a', total: 1840));

      expect(r.tipo, TipoResultado.aviso);
      expect(r.mensaje, contains('19,40'));
      expect(r.mensaje, contains('18,40'));
    });

    test('confirmar uno que otro vendedor ya tocó lo dice', () async {
      repo.resultadoConfirmar = const ResultadoConfirmar(yaNoEsNuevo: true);

      final r = await provider.confirmar(_p('a'));

      expect(r.fallo, isTrue);
      expect(r.mensaje, contains('ya no está nuevo'));
    });

    test('el doble toque no repite la acción', () async {
      repo.esperaAlConfirmar = Completer<void>();
      final a = _p('a');

      final primera = provider.confirmar(a);
      final segunda = await provider.confirmar(a);

      expect(provider.procesando('a'), isTrue);
      expect(segunda.hizoAlgo, isFalse);
      repo.esperaAlConfirmar!.complete();
      await primera;
      expect(provider.procesando('a'), isFalse);
      expect(repo.llamadas, ['confirmar:a']);
    });

    test('confirmar quita la copia vieja traída con «Ver más»', () async {
      provider = crear(tamano: 2);
      provider.iniciar();
      repo.emitir(_nuevos, [_p('c', hora: 12), _p('b', hora: 11)]);
      await Future<void>.delayed(Duration.zero);
      repo.paginas.add(
        PaginaPedidos(
          pedidos: [_p('a', hora: 10)],
          ultimoCursor: null,
          hayMas: false,
        ),
      );
      await provider.verMas(PestanaPedidos.nuevos);

      await provider.confirmar(_p('a', hora: 10));

      expect(provider.pedidosDe(PestanaPedidos.nuevos).map((p) => p.id), [
        'c',
        'b',
      ]);
    });

    test('cancelar avisa si algo no se pudo devolver', () async {
      repo.omitidosAlCancelar = 2;

      final r = await provider.cancelar(_p('a'));

      expect(r.tipo, TipoResultado.aviso);
      expect(r.mensaje, contains('2 productos que ya no existen'));
    });

    test('cancelar un pedido que ya no se puede muestra el motivo', () async {
      repo.falloAlCancelar['a'] = StateError(
        'El pedido ya no se puede cancelar.',
      );

      final r = await provider.cancelar(_p('a'));

      expect(r.fallo, isTrue);
      expect(r.mensaje, 'El pedido ya no se puede cancelar.');
    });

    test('un error inesperado no muestra detalles internos', () async {
      repo.falloAlCancelar['a'] = Exception('permission-denied: uid=123');

      final r = await provider.cancelar(_p('a'));

      expect(r.fallo, isTrue);
      expect(r.mensaje, isNot(contains('permission-denied')));
      expect(r.mensaje, contains('conexión'));
    });

    test('avanzar dice a qué estado pasó', () async {
      final r = await provider.avanzar(
        _p('a', estado: EstadoPedido.confirmado),
      );

      expect(r.mensaje, 'Pedido en camino.');
    });

    test('entregar y cobrar marca el pago a la vez', () async {
      await provider.avanzar(
        _p('a', estado: EstadoPedido.enCamino),
        cobrado: true,
      );

      expect(repo.estadoAvanzado, EstadoPedido.entregado);
      expect(repo.pagoAvanzado, EstadoPago.pagado);
    });

    test(
      'avanzar un pedido nuevo es un error claro, no una escritura',
      () async {
        final r = await provider.avanzar(_p('a'));

        expect(r.fallo, isTrue);
        expect(repo.llamadas, isEmpty);
      },
    );

    test('marcar pago y reembolso', () async {
      final pago = await provider.marcarPago(_p('a'), EstadoPago.pagado);
      final reembolso = await provider.marcarReembolsoHecho(_p('b'));

      expect(pago.mensaje, 'Marcado como cobrado.');
      expect(reembolso.tipo, TipoResultado.exito);
      expect(repo.llamadas, ['pago:a:pagado', 'reembolso:b']);
    });
  });

  group('cancelar vencidos', () {
    test(
      'repite por tandas hasta que no queda más y suma el resultado',
      () async {
        provider = crear(tamano: 2);
        repo.tandasVencidos
          ..add([_p('a'), _p('b')])
          ..add([_p('c')]);

        final r = await provider.cancelarVencidos();

        expect(r.mensaje, 'Se cancelaron 3 pedidos.');
        expect(repo.llamadas, [
          'cancelar:a:true',
          'cancelar:b:true',
          'cancelar:c:true',
        ]);
        expect(provider.cancelandoVencidos, isFalse);
      },
    );

    test('se detiene si una tanda no cancela ninguno', () async {
      provider = crear(tamano: 2);
      repo.falloAlCancelar['a'] = Exception('sin conexión');
      repo.falloAlCancelar['b'] = Exception('sin conexión');
      repo.tandasVencidos
        ..add([_p('a'), _p('b')])
        ..add([_p('a'), _p('b')]);

      final r = await provider.cancelarVencidos();

      expect(r.tipo, TipoResultado.aviso);
      expect(r.mensaje, contains('2 no se pudieron cancelar'));
      expect(repo.llamadas, hasLength(2));
    });

    test('sin vencidos lo dice', () async {
      final r = await provider.cancelarVencidos();

      expect(r.mensaje, 'No hay pedidos vencidos.');
    });

    test('usa el corte de 12 horas del reloj dado', () async {
      await provider.cancelarVencidos();

      expect(repo.corteVencidos, DateTime.utc(2026, 11, 5, 8));
    });

    test('un segundo toque mientras trabaja se ignora', () async {
      repo.tandasVencidos.add([_p('a')]);
      repo.falloAlCancelar['a'] = Exception('x');

      final primera = provider.cancelarVencidos();
      final segunda = await provider.cancelarVencidos();

      expect(segunda.hizoAlgo, isFalse);
      await primera;
    });

    test('cuenta los vencidos ya cargados para el botón', () async {
      provider.iniciar();
      repo.emitir(_nuevos, [_p('viejo', hora: 1), _p('reciente', hora: 19)]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.vencidosCargados, 1);
    });
  });
}
