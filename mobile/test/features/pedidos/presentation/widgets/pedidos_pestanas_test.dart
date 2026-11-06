import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/filtro_pedidos.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/pedidos_dependencies.dart';
import 'package:mobile/features/pedidos/presentation/widgets/pedidos_flow.dart';

import '../../helpers/repositorio_pedidos_fake.dart';

final _ahora = DateTime.utc(2026, 11, 5, 20);

Pedido _pedido(
  String id, {
  String nombre = 'Rosa Quispe',
  String clave = '7GHMHF',
  EstadoPedido estado = EstadoPedido.nuevo,
  EstadoPago pago = EstadoPago.pendiente,
  EstadoReembolso reembolso = EstadoReembolso.ninguno,
}) {
  return Pedido(
    id: id,
    clave: clave,
    estado: estado,
    estadoPago: pago,
    reembolso: reembolso,
    fecha: _ahora.subtract(const Duration(minutes: 4)),
    cliente: ClientePedido(nombre: nombre, telefono: '987 654 321'),
    metodoPago: 'Yape',
    totalCentavos: 1840,
    subtotalCentavos: 1840,
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

/// La pestaña (no el número de arriba, que puede decir lo mismo).
Finder pestana(String texto) =>
    find.descendant(of: find.byType(Wrap), matching: find.text(texto));

void main() {
  late RepositorioPedidosFake repo;

  Future<void> abrir(WidgetTester tester, {required Size tamano}) async {
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
    repo.emitir(FiltroPedidos.nuevos, [_pedido('a')]);
    repo.emitir(FiltroPedidos.activos, const []);
    await tester.pump();
    await tester.pump();
  }

  setUp(() => repo = RepositorioPedidosFake());

  group('celular y tableta: 4 pestañas', () {
    const tamano = Size(375, 800);

    testWidgets('Nuevos, Activos, Por cobrar y Reembolsos, sin Todos', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano);

      expect(find.text('Nuevos 1'), findsOneWidget);
      expect(find.text('Activos 0'), findsOneWidget);
      expect(pestana('Por cobrar'), findsOneWidget);
      expect(pestana('Reembolsos'), findsOneWidget);
      expect(pestana('Todos'), findsNothing);
    });

    testWidgets('«Por cobrar» exacto sale de la suma de todo el negocio', (
      tester,
    ) async {
      repo.sumaPorCobrar = 56400;
      await abrir(tester, tamano: tamano);

      expect(find.text('564,00'), findsOneWidget);
      expect(find.text('Por cobrar (cargados)'), findsNothing);
    });

    testWidgets('si la suma falla, dice que es de lo cargado', (tester) async {
      repo.sumaPorCobrar = null;
      await abrir(tester, tamano: tamano);

      expect(find.text('Por cobrar (cargados)'), findsOneWidget);
    });

    testWidgets('abrir Por cobrar muestra sus pedidos con el número', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano);

      await tester.tap(pestana('Por cobrar'));
      await tester.pump();
      repo.emitir(FiltroPedidos.porCobrar, [
        _pedido(
          'e',
          nombre: 'Luis Vega',
          clave: 'X8D4LQ',
          estado: EstadoPedido.entregado,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Luis Vega'), findsOneWidget);
      expect(find.text('Por cobrar 1'), findsOneWidget);
      expect(repo.oyentesDe(FiltroPedidos.porCobrar), 1);
    });

    testWidgets('un entregado sin cobrar se puede marcar como cobrado', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano);
      await tester.tap(pestana('Por cobrar'));
      await tester.pump();
      repo.emitir(FiltroPedidos.porCobrar, [
        _pedido('e', estado: EstadoPedido.entregado),
      ]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como cobrado'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['pago:e:pagado']);
    });

    testWidgets('en Reembolsos se marca el reembolso como hecho', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano);
      await tester.tap(pestana('Reembolsos'));
      await tester.pump();
      repo.emitir(FiltroPedidos.reembolsos, [
        _pedido(
          'r',
          estado: EstadoPedido.cancelado,
          pago: EstadoPago.pagado,
          reembolso: EstadoReembolso.pendiente,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Reembolso pendiente'), findsOneWidget);
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar reembolso hecho'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['reembolso:r']);
      expect(find.text('Reembolso marcado como hecho.'), findsOneWidget);
    });

    testWidgets('sin reembolsos pendientes lo dice', (tester) async {
      await abrir(tester, tamano: tamano);

      await tester.tap(pestana('Reembolsos'));
      await tester.pump();
      repo.emitir(FiltroPedidos.reembolsos, const []);
      await tester.pump();
      await tester.pump();

      expect(find.text('No hay reembolsos pendientes.'), findsOneWidget);
    });

    testWidgets('al volver a Nuevos se cierra la consulta de la otra pestaña', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano);
      await tester.tap(pestana('Reembolsos'));
      await tester.pump();
      expect(repo.oyentesDe(FiltroPedidos.reembolsos), 1);

      await tester.tap(find.text('Nuevos 1'));
      await tester.pump();

      expect(repo.oyentesDe(FiltroPedidos.reembolsos), 0);
    });
  });

  group('PC: 5 pestañas', () {
    const tamano = Size(1500, 900);

    testWidgets('trae también «Todos» y su tabla', (tester) async {
      await abrir(tester, tamano: tamano);

      expect(pestana('Todos'), findsOneWidget);
      await tester.tap(pestana('Todos'));
      await tester.pump();
      repo.emitir(FiltroPedidos.todos, [
        _pedido('a'),
        _pedido(
          'c',
          nombre: 'Luis Vega',
          clave: 'X8D4LQ',
          estado: EstadoPedido.confirmado,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Luis Vega'), findsOneWidget);
      expect(find.text('Rosa Quispe'), findsOneWidget);
      expect(find.text('Todos 2'), findsOneWidget);
    });

    testWidgets('en Reembolsos la tabla dice «Reembolso pendiente»', (
      tester,
    ) async {
      await abrir(tester, tamano: tamano);
      await tester.tap(pestana('Reembolsos'));
      await tester.pump();
      repo.emitir(FiltroPedidos.reembolsos, [
        _pedido(
          'r',
          estado: EstadoPedido.cancelado,
          pago: EstadoPago.pagado,
          reembolso: EstadoReembolso.pendiente,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Reembolso pendiente'), findsOneWidget);
    });

    testWidgets('el número grande de Por cobrar es exacto y lo dice', (
      tester,
    ) async {
      repo.sumaPorCobrar = 56400;
      await abrir(tester, tamano: tamano);

      expect(find.text('564,00'), findsOneWidget);
      expect(find.text('de todo el negocio'), findsOneWidget);
    });
  });
}
