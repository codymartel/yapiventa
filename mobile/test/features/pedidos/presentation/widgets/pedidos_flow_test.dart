import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/pedidos_dependencies.dart';
import 'package:mobile/features/pedidos/presentation/widgets/pedidos_flow.dart';
import 'package:mobile/features/pedidos/presentation/widgets/tarjeta_pedido.dart';

import '../../helpers/repositorio_pedidos_fake.dart';

const _nuevos = {EstadoPedido.nuevo};
const _activos = {
  EstadoPedido.confirmado,
  EstadoPedido.enCamino,
  EstadoPedido.listo,
};
final _ahora = DateTime.utc(2026, 11, 5, 20);

Pedido _pedido(
  String id, {
  String nombre = 'Rosa Quispe',
  EstadoPedido estado = EstadoPedido.nuevo,
  EstadoPago pago = EstadoPago.pendiente,
  Duration hace = const Duration(minutes: 4),
  String telefono = '987 654 321',
}) {
  return Pedido(
    id: id,
    clave: '7GHMHF',
    estado: estado,
    estadoPago: pago,
    fecha: _ahora.subtract(hace),
    cliente: ClientePedido(nombre: nombre, telefono: telefono),
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
  late List<Uri> enlaces;

  Future<void> abrir(
    WidgetTester tester, {
    required Size tamano,
    List<Pedido> nuevos = const [],
    List<Pedido> activos = const [],
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
            abrirEnlace: (uri) async {
              enlaces.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    repo.emitir(_nuevos, nuevos);
    repo.emitir(_activos, activos);
    await tester.pump();
    await tester.pump();
  }

  setUp(() {
    repo = RepositorioPedidosFake();
    enlaces = [];
  });

  group('celular vertical (menos de 600 px)', () {
    const tamano = Size(375, 800);

    testWidgets('muestra la lista con el cliente y el total, sin símbolo', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano, nuevos: [_pedido('a')]);

      expect(find.text('Rosa Quispe'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TarjetaPedido),
          matching: find.text('18,40'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('S/'), findsNothing);
      expect(find.text('Nuevos 1'), findsOneWidget);
      expect(find.text('Activos 0'), findsOneWidget);
    });

    testWidgets('tocar un pedido abre la hoja y confirmar llama al caso', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano, nuevos: [_pedido('a')]);

      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar pedido'), findsOneWidget);

      await tester.tap(find.text('Confirmar pedido'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['confirmar:a']);
      expect(find.text('Pedido confirmado.'), findsOneWidget);
    });

    testWidgets('sin pedidos dice que no hay y no muestra error', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano);

      expect(find.text('No hay pedidos nuevos.'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('cambiar a Activos muestra lo suyo', (tester) async {
      await abrir(
        tester,
        tamano: tamano,
        nuevos: [_pedido('a')],
        activos: [
          _pedido('b', nombre: 'Luis Vega', estado: EstadoPedido.confirmado),
        ],
      );

      await tester.tap(find.text('Activos 1'));
      await tester.pump();

      expect(find.text('Luis Vega'), findsOneWidget);
      expect(find.text('Rosa Quispe'), findsNothing);
    });

    testWidgets('un error de conexión muestra el aviso con Reintentar', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano);

      repo.fallar(_nuevos);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('un nombre con etiquetas se muestra como texto', (
      tester,
    ) async {
      await abrir(
        tester,
        tamano: tamano,
        nuevos: [_pedido('a', nombre: '<script>alert(1)</script>')],
      );

      expect(find.text('<script>alert(1)</script>'), findsOneWidget);
    });

    testWidgets('un pedido vencido se marca y deja cancelar los vencidos', (
      tester,
    ) async {
      await abrir(
        tester,
        tamano: tamano,
        nuevos: [_pedido('v', hace: const Duration(hours: 13))],
      );

      expect(find.text('Vencido'), findsOneWidget);
      expect(find.text('Cancelar vencidos (1)'), findsOneWidget);

      repo.tandasVencidos.add([_pedido('v', hace: const Duration(hours: 13))]);
      await tester.tap(find.text('Cancelar vencidos (1)'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cancelar el pedido vencido?'), findsOneWidget);

      await tester.tap(find.text('Cancelar vencidos').last);
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['cancelar:v:true']);
    });

    testWidgets('cancelar un pedido pide confirmar antes', (tester) async {
      await abrir(tester, tamano: tamano, nuevos: [_pedido('a')]);
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cancelar el pedido 7GHMHF?'), findsOneWidget);
      expect(repo.llamadas, isEmpty);

      await tester.tap(find.text('Cancelar pedido'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['cancelar:a:false']);
    });

    testWidgets(
      'entregar sin cobrar pregunta «¿Ya cobraste?» y marca el pago',
      (tester) async {
        await abrir(
          tester,
          tamano: tamano,
          activos: [_pedido('e', estado: EstadoPedido.enCamino)],
        );
        await tester.tap(find.text('Activos 1'));
        await tester.pump();
        await tester.tap(find.text('Rosa Quispe'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Marcar entregado'));
        await tester.pumpAndSettle();
        expect(find.text('¿Ya cobraste?'), findsOneWidget);

        await tester.tap(find.text('Sí, ya cobré'));
        await tester.pumpAndSettle();

        expect(repo.estadoAvanzado, EstadoPedido.entregado);
        expect(repo.pagoAvanzado, EstadoPago.pagado);
      },
    );

    testWidgets('entregar uno ya pagado no pregunta nada', (tester) async {
      await abrir(
        tester,
        tamano: tamano,
        activos: [
          _pedido('e', estado: EstadoPedido.enCamino, pago: EstadoPago.pagado),
        ],
      );
      await tester.tap(find.text('Activos 1'));
      await tester.pump();
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Marcar entregado'));
      await tester.pumpAndSettle();

      expect(find.text('¿Ya cobraste?'), findsNothing);
      expect(repo.estadoAvanzado, EstadoPedido.entregado);
      expect(repo.pagoAvanzado, isNull);
    });

    testWidgets('WhatsApp abre un enlace solo con dígitos', (tester) async {
      await abrir(tester, tamano: tamano, nuevos: [_pedido('a')]);
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();

      expect(enlaces.single.host, 'wa.me');
      expect(enlaces.single.path, '/51987654321');
    });

    testWidgets('sin teléfono no hay botón de WhatsApp', (tester) async {
      await abrir(
        tester,
        tamano: tamano,
        nuevos: [_pedido('a', telefono: '')],
      );
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();

      expect(find.text('WhatsApp'), findsNothing);
    });
  });

  group('celular horizontal (lista y detalle lado a lado)', () {
    const tamano = Size(800, 400);

    testWidgets('al inicio pide elegir un pedido', (tester) async {
      await abrir(tester, tamano: tamano, nuevos: [_pedido('a')]);

      expect(find.text('Elige un pedido para ver el detalle.'), findsOneWidget);
      expect(find.text('Confirmar pedido'), findsNothing);
    });

    testWidgets('elegir un pedido muestra el detalle sin abrir hoja', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano, nuevos: [_pedido('a')]);

      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar pedido'), findsOneWidget);
      expect(find.text('Elige un pedido para ver el detalle.'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('al confirmar, el detalle sigue al pedido a Activos', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano, nuevos: [_pedido('a')]);
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();

      // El pedido pasa de Nuevos a Activos (lo emite el listener en vivo).
      repo.emitir(_nuevos, const []);
      repo.emitir(_activos, [_pedido('a', estado: EstadoPedido.confirmado)]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Enviar a domicilio'), findsOneWidget);
    });
  });

  group('tableta vertical (lista y panel lateral)', () {
    const tamano = Size(800, 1100);

    testWidgets('el detalle entra como panel y se puede cerrar', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano, nuevos: [_pedido('a')]);

      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar pedido'), findsOneWidget);
      expect(find.byTooltip('Cerrar detalle'), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar detalle'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar pedido'), findsNothing);
    });
  });

  group('listeners', () {
    testWidgets('al salir de la pantalla se cierran los dos', (tester) async {
      await abrir(tester, tamano: const Size(375, 800));
      expect(repo.oyentesActivos, 2);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(repo.oyentesActivos, 0);
    });
  });
}
