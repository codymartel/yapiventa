import 'package:flutter/material.dart';
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
  String telefono = '987 654 321',
  EstadoPedido estado = EstadoPedido.nuevo,
  EstadoPago pago = EstadoPago.pendiente,
  Duration hace = const Duration(minutes: 4),
  String zona = 'Zona Norte',
  List<LineaPedido>? lineas,
}) {
  final llegada = _ahora.subtract(hace);
  return Pedido(
    id: id,
    clave: clave,
    estado: estado,
    estadoPago: pago,
    fecha: llegada,
    cliente: ClientePedido(nombre: nombre, telefono: telefono),
    zona: zona,
    metodoPago: 'Yape',
    subtotalCentavos: 1540,
    deliveryCentavos: 300,
    totalCentavos: 1840,
    notas: 'Sin hielo, por favor',
    historial: [CambioEstado(estado: EstadoPedido.nuevo, fecha: llegada)],
    lineas:
        lineas ??
        const [
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
    Size tamano = const Size(1500, 900),
    List<Pedido> nuevos = const [],
    List<Pedido> activos = const [],
    ResumenVentasDia? resumen,
  }) async {
    tester.view.physicalSize = tamano;
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

  testWidgets('muestra los 6 números del día con el resumen y el ticket', (
    tester,
  ) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a'),
        _pedido('b', hace: const Duration(minutes: 21)),
      ],
      activos: [_pedido('c', estado: EstadoPedido.enCamino)],
      resumen: const ResumenVentasDia(
        dia: '2026-11-05',
        ventasCentavos: 21460,
        entregados: 9,
        confirmados: 4,
        sumaMinutosConfirmar: 26,
      ),
    );

    expect(find.text('el más viejo: 21 min'), findsOneWidget);
    expect(find.text('1 en camino'), findsOneWidget);
    expect(find.text('214,60'), findsOneWidget);
    expect(find.text('9 entregados · ticket 23,84'), findsOneWidget);
    expect(find.text('6 min'), findsOneWidget);
    expect(find.text('Vencidos (+12 h)'), findsOneWidget);
  });

  testWidgets('sin entregas el ticket y el tiempo son «—», no un cero falso', (
    tester,
  ) async {
    await abrir(tester, nuevos: [_pedido('a')]);

    expect(find.text('0 entregados · ticket —'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets(
    'la tabla trae cliente, teléfono, zona, productos, pago y total',
    (tester) async {
      await abrir(tester, nuevos: [_pedido('a')]);

      expect(find.text('7GHMHF'), findsOneWidget);
      expect(find.text('Rosa Quispe'), findsOneWidget);
      expect(find.text('987 654 321'), findsOneWidget);
      expect(find.text('Zona Norte'), findsOneWidget);
      expect(find.text('2× Gaseosa Inca'), findsOneWidget);
      expect(find.text('Sin cobrar'), findsOneWidget);
      expect(find.text('PRODUCTOS'), findsOneWidget);
    },
  );

  testWidgets('con poco ancho la tabla oculta Productos y no se desborda', (
    tester,
  ) async {
    await abrir(tester, tamano: const Size(1100, 800), nuevos: [_pedido('a')]);

    expect(find.text('PRODUCTOS'), findsNothing);
    expect(find.text('Rosa Quispe'), findsOneWidget);
  });

  testWidgets('«por preparar» suma lo de los pedidos nuevos y confirmados', (
    tester,
  ) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a'),
        _pedido('b', clave: 'K3M9TA'),
      ],
      activos: [_pedido('c', estado: EstadoPedido.confirmado)],
    );

    expect(find.textContaining('POR PREPARAR AHORA'), findsOneWidget);
    expect(find.textContaining('Gaseosa Inca ×6'), findsOneWidget);
  });

  testWidgets('buscar filtra la tabla entre los cargados', (tester) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a'),
        _pedido(
          'b',
          nombre: 'Juan Paredes',
          clave: 'K3M9TA',
          telefono: '912 345 678',
        ),
      ],
    );

    await tester.enterText(find.byType(TextField), 'juan');
    await tester.pump();
    expect(find.text('Juan Paredes'), findsOneWidget);
    expect(find.text('Rosa Quispe'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(
      find.text('Sin resultados entre los pedidos cargados.'),
      findsOneWidget,
    );
  });

  testWidgets('elegir un pedido muestra el detalle con historial y la nota', (
    tester,
  ) async {
    await abrir(tester, nuevos: [_pedido('a')]);
    expect(
      find.text('Elige un pedido para ver el detalle completo.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Rosa Quispe'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar pedido'), findsOneWidget);
    expect(find.text('HISTORIAL'), findsOneWidget);
    expect(find.textContaining('Nota del cliente'), findsOneWidget);
    expect(find.textContaining('llegó a las'), findsOneWidget);
  });

  testWidgets('elegir varios y confirmarlos en lote', (tester) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a'),
        _pedido('b', nombre: 'Juan', clave: 'K3M9TA'),
      ],
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Confirmar seleccionados'),
          )
          .onPressed,
      isNull,
    );

    final casillas = find.byType(Checkbox);
    await tester.tap(casillas.at(1));
    await tester.tap(casillas.at(2));
    await tester.pump();
    expect(find.text('2 seleccionados'), findsOneWidget);

    await tester.tap(find.text('Confirmar seleccionados'));
    await tester.pumpAndSettle();

    expect(repo.llamadas, ['confirmar:a', 'confirmar:b']);
    expect(find.text('Se confirmaron 2 pedidos.'), findsOneWidget);
  });

  testWidgets('la casilla de arriba marca todos los visibles', (tester) async {
    await abrir(
      tester,
      nuevos: [
        _pedido('a'),
        _pedido('b', clave: 'K3M9TA'),
      ],
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('2 seleccionados'), findsOneWidget);
  });

  testWidgets('en Activos no hay casillas ni lote', (tester) async {
    await abrir(
      tester,
      activos: [_pedido('c', estado: EstadoPedido.confirmado)],
    );

    await tester.tap(find.text('Activos 1'));
    await tester.pump();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Confirmar seleccionados'), findsNothing);
  });

  testWidgets('un nombre con etiquetas se muestra como texto', (tester) async {
    await abrir(
      tester,
      nuevos: [_pedido('a', nombre: '<script>alert(1)</script>')],
    );

    expect(find.text('<script>alert(1)</script>'), findsOneWidget);
  });

  testWidgets('un pedido vencido sale con su etiqueta en la tabla', (
    tester,
  ) async {
    await abrir(
      tester,
      nuevos: [_pedido('v', hace: const Duration(hours: 13))],
    );

    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('Cancelar vencidos (1)'), findsOneWidget);
  });
}
