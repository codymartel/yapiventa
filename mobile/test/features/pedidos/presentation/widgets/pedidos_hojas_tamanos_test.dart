import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/pedidos/domain/models/filtro_pedidos.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/pedidos_dependencies.dart';
import 'package:mobile/features/pedidos/presentation/widgets/pedidos_flow.dart';

import '../../helpers/repositorio_pedidos_fake.dart';

// Las hojas de Pedidos en pantallas chicas y de lado: nada se aplasta, el
// botón principal queda entero a la vista y el aviso de abajo flota (no tapa
// los botones). Pedidos no tiene campos de texto en sus hojas: el teclado no
// aplica aquí (la búsqueda de PC no es una hoja).

final _ahora = DateTime.utc(2026, 11, 5, 20);

Pedido _pedido(String id) {
  return Pedido(
    id: id,
    clave: '7GHMHF',
    fecha: _ahora.subtract(const Duration(minutes: 4)),
    cliente: const ClientePedido(
      nombre: 'Rosa Quispe',
      telefono: '987 654 321',
    ),
    subtotalCentavos: 1540,
    deliveryCentavos: 300,
    totalCentavos: 1840,
    lineas: [
      for (var i = 0; i < 8; i++)
        LineaPedido(
          productoId: 'p$i',
          nombre: 'Producto de prueba $i',
          cantidad: 2,
          precioCentavos: 350,
        ),
    ],
  );
}

void main() {
  late RepositorioPedidosFake repo;

  Future<void> abrir(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.oscuro,
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

  /// El botón está entero dentro de la pantalla (no cortado ni tapado).
  void expectEnteroEnPantalla(WidgetTester tester, Finder boton, Size tamano) {
    final rect = tester.getRect(boton);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(tamano.height));
    expect(rect.right, lessThanOrEqualTo(tamano.width));
    expect(rect.height, greaterThanOrEqualTo(44));
  }

  setUp(() => repo = RepositorioPedidosFake());

  testWidgets('celular chico (320 × 568): la hoja del pedido se desliza y '
      '«Confirmar pedido» queda fijo y entero', (tester) async {
    const tamano = Size(320, 568);
    await abrir(tester, tamano);

    await tester.tap(find.text('Rosa Quispe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expectEnteroEnPantalla(
      tester,
      find.widgetWithText(FilledButton, 'Confirmar pedido'),
      tamano,
    );
  });

  testWidgets('celular de lado (640 × 320): lista y detalle lado a lado, '
      'sin desbordes y con el botón a la vista', (tester) async {
    const tamano = Size(640, 320);
    await abrir(tester, tamano);

    await tester.tap(find.text('Rosa Quispe'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsNothing);
    expectEnteroEnPantalla(
      tester,
      find.widgetWithText(FilledButton, 'Confirmar pedido'),
      tamano,
    );
  });

  testWidgets('el aviso de abajo flota: no tapa los botones de la hoja', (
    tester,
  ) async {
    await abrir(tester, const Size(375, 800));
    await tester.tap(find.text('Rosa Quispe'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar pedido'));
    await tester.pump();

    final aviso = tester.widget<SnackBar>(find.byType(SnackBar));
    final tema = Theme.of(tester.element(find.byType(SnackBar)));
    expect(
      aviso.behavior ?? tema.snackBarTheme.behavior,
      SnackBarBehavior.floating,
    );
  });
}
