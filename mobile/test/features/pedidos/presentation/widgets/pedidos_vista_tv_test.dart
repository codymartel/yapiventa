import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/filtro_pedidos.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';
import 'package:mobile/features/pedidos/pedidos_dependencies.dart';
import 'package:mobile/features/pedidos/presentation/widgets/pedidos_flow.dart';

import '../../helpers/repositorio_pedidos_fake.dart';

const _nuevos = FiltroPedidos.nuevos;
const _activos = FiltroPedidos.activos;
final _ahora = DateTime.utc(2026, 11, 5, 20);

Pedido _pedido(
  String id, {
  String nombre = 'Rosa Quispe',
  String clave = '7GHMHF',
  EstadoPedido estado = EstadoPedido.nuevo,
  EstadoPago pago = EstadoPago.pendiente,
  Duration hace = const Duration(minutes: 4),
}) {
  return Pedido(
    id: id,
    clave: clave,
    estado: estado,
    estadoPago: pago,
    fecha: _ahora.subtract(hace),
    cliente: ClientePedido(nombre: nombre, telefono: '987 654 321'),
    zona: 'Zona Norte',
    metodoPago: 'Yape',
    subtotalCentavos: 1540,
    deliveryCentavos: 300,
    totalCentavos: 1840,
    lineas: const [
      LineaPedido(
        productoId: 'inca',
        nombre: 'Gaseosa Inca',
        cantidad: 2,
        precioCentavos: 350,
      ),
    ],
  );
}

void main() {
  late RepositorioPedidosFake repo;

  Future<void> abrir(
    WidgetTester tester, {
    List<Pedido> nuevos = const [],
    List<Pedido> activos = const [],
    ResumenVentasDia? resumen,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidosFlow(
            negocioId: 'n1',
            dependencias: PedidosDependencies.conRepositorio(repo),
            reloj: () => _ahora,
            abrirEnlace: (_) async => true,
          ),
        ),
      ),
    );
    repo.emitir(_nuevos, nuevos);
    repo.emitir(_activos, activos);
    if (resumen != null) repo.emitirResumen(resumen);
    await tester.pump();
    await tester.pump();
  }

  setUp(() => repo = RepositorioPedidosFake());

  testWidgets('el encabezado trae el título, los nuevos, la hora y «en vivo»', (
    tester,
  ) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a'),
        _pedido('b', clave: 'K3M9TA'),
      ],
    );

    expect(find.text('YapiVenta · Pedidos'), findsOneWidget);
    expect(find.text('2 nuevos'), findsOneWidget);
    // 20:00 UTC son las 15:00 en Lima.
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('● En vivo'), findsOneWidget);
  });

  testWidgets('una sola tabla con los pedidos nuevos y los activos', (
    tester,
  ) async {
    await abrir(
      tester,
      nuevos: [_pedido('a', hace: const Duration(minutes: 4))],
      activos: [
        _pedido(
          'c',
          nombre: 'Luis Vega',
          clave: 'X8D4LQ',
          estado: EstadoPedido.confirmado,
          hace: const Duration(minutes: 52),
        ),
      ],
    );

    expect(find.text('Rosa Quispe'), findsOneWidget);
    expect(find.text('Luis Vega'), findsOneWidget);
    expect(find.text('PRODUCTOS'), findsOneWidget);
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
  });

  testWidgets('muestra las ventas de hoy, el ticket y los últimos entregados', (
    tester,
  ) async {
    await abrir(
      tester,
      nuevos: [_pedido('a')],
      resumen: ResumenVentasDia(
        dia: '2026-11-05',
        ventasCentavos: 21460,
        entregados: 9,
        ultimosEntregados: [
          EntregadoReciente(
            pedidoId: 'x',
            cliente: 'Carla Mena',
            productos: '2× Combo familiar',
            totalCentavos: 2100,
            metodoPago: 'Yape',
            cobrado: true,
            hora: DateTime.utc(2026, 11, 5, 20, 40),
          ),
        ],
      ),
    );

    expect(find.text('9 entregados · ticket 23,84'), findsOneWidget);
    expect(find.text('Últimos entregados hoy'), findsOneWidget);
    expect(find.text('15:40 · Carla Mena · 2× Combo familiar'), findsOneWidget);
    expect(find.text('Yape · pagado · 21,00'), findsOneWidget);
  });

  testWidgets('sin entregas lo dice, y sin pedidos no hay avisos', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('No hay pedidos abiertos.'), findsOneWidget);
    expect(
      find.text('Todavía no se entregó ningún pedido hoy.'),
      findsOneWidget,
    );
    expect(find.text('Nada por preparar.'), findsOneWidget);
    expect(find.text('Todo en orden.'), findsOneWidget);
  });

  testWidgets('«por preparar» y «atención» con vencidos y sin cobrar', (
    tester,
  ) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a'),
        _pedido('v', clave: 'P2QW8D', hace: const Duration(hours: 13)),
      ],
    );

    expect(find.text('Por preparar ahora'), findsOneWidget);
    expect(find.text('Gaseosa Inca'), findsOneWidget);
    expect(find.text('×4'), findsOneWidget);
    expect(find.text('Atención'), findsOneWidget);
    expect(find.text('⚠ 1 pedido vencido (+12 h)'), findsOneWidget);
    expect(find.text('⚠ 2 pedidos sin cobrar'), findsOneWidget);
  });

  testWidgets('la barra de ayuda dice las teclas del control remoto', (
    tester,
  ) async {
    await abrir(tester, nuevos: [_pedido('a')]);

    expect(find.textContaining('mover'), findsOneWidget);
    expect(find.textContaining('abrir el pedido'), findsOneWidget);
    expect(find.textContaining('volver'), findsOneWidget);
  });

  testWidgets('OK abre el detalle del pedido con el foco y se confirma ahí', (
    tester,
  ) async {
    await abrir(tester, nuevos: [_pedido('a')]);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Confirmar pedido'), findsOneWidget);
    expect(find.textContaining('HISTORIAL'), findsNothing);

    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();

    expect(repo.llamadas, ['confirmar:a']);
  });

  testWidgets('▼ mueve el foco al siguiente pedido y OK abre ese', (
    tester,
  ) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a', nombre: 'Rosa Quispe', hace: const Duration(minutes: 4)),
        _pedido(
          'b',
          nombre: 'Juan Paredes',
          clave: 'K3M9TA',
          hace: const Duration(minutes: 21),
        ),
      ],
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('K3M9TA'), findsWidgets);
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(repo.llamadas, ['confirmar:b']);
  });

  testWidgets('el foco no pasa del último ni del primero', (tester) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a', hace: const Duration(minutes: 4)),
        _pedido('b', clave: 'K3M9TA', hace: const Duration(minutes: 21)),
      ],
    );

    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(repo.llamadas, ['confirmar:b']);

    // Arriba: de nuevo hasta el primero.
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Atrás (Escape) cierra el detalle', (tester) async {
    await abrir(tester, nuevos: [_pedido('a')]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Confirmar pedido'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar pedido'), findsNothing);
  });

  testWidgets('sin pedidos, OK y las flechas no hacen nada ni fallan', (
    tester,
  ) async {
    await abrir(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Confirmar pedido'), findsNothing);
  });

  testWidgets('un nombre con etiquetas se muestra como texto', (tester) async {
    await abrir(
      tester,
      nuevos: [_pedido('a', nombre: '<script>alert(1)</script>')],
    );

    expect(find.text('<script>alert(1)</script>'), findsOneWidget);
  });
}
