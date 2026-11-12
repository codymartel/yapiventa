import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/caja/presentation/providers/venta_caja_provider.dart';
import 'package:mobile/features/caja/presentation/widgets/entrega_pago_caja.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/pedido_por.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

const _efectivo = OpcionPagoCaja(id: 'efectivo', etiqueta: 'Efectivo');
const _centro = ZonaCaja(nombre: 'Centro', costoCentavos: 300);

class _RepoFalso implements RepositorioVentasMostrador {
  final List<SolicitudVentaMostrador> pedidas = [];

  @override
  Future<ResultadoVentaMostrador> registrar(
    String negocioId,
    SolicitudVentaMostrador solicitud,
  ) async {
    pedidas.add(solicitud);
    return const ResultadoVentaMostrador(
      registrada: true,
      pedidoId: 'v',
      clave: 'ABC123',
    );
  }

  @override
  Future<ResultadoAnulacion> anular(String negocioId, String pedidoId) async =>
      const ResultadoAnulacion();
}

/// Paso R en Caja: «En tienda» pregunta «¿Lo pidió antes para recoger?» y lo
/// manda con la venta; delivery nunca lo lleva.
void main() {
  late _RepoFalso repo;

  VentaCajaProvider crear() {
    var n = 0;
    return VentaCajaProvider(
      negocioId: 'n1',
      registrar: RegistrarVentaMostrador(repo),
      opcionesPago: const [_efectivo],
      zonas: const [_centro],
      generarId: () => 'id-${++n}',
    );
  }

  setUp(() => repo = _RepoFalso());

  group('VentaCajaProvider', () {
    test('empieza en «No» y manda lo elegido al cobrar', () async {
      final p = crear();
      expect(p.pedidoPor, isNull);
      p.agregarProducto(productoSimple(precioCentavos: 450), cantidad: 2);

      p.elegirPedidoPor(PedidoPor.whatsapp);
      await p.cobrar();

      final s = repo.pedidas.single;
      expect(s.pedidoPor, PedidoPor.whatsapp);
      expect(s.enLocal, isTrue);
      expect(s.totalCentavos, 900);
      expect(p.pedidoPor, isNull, reason: 'la venta nueva vuelve a «No»');
    });

    test('pasar a delivery lo borra y en delivery no se puede elegir', () {
      final p = crear();
      p.elegirPedidoPor(PedidoPor.facebook);

      p.elegirEntrega(EntregaCaja.delivery);
      expect(p.pedidoPor, isNull);

      p.elegirPedidoPor(PedidoPor.llamada);
      expect(p.pedidoPor, isNull);
    });

    test('vaciar la venta también vuelve a «No»', () {
      final p = crear();
      p.elegirPedidoPor(PedidoPor.otro);

      p.vaciar();

      expect(p.pedidoPor, isNull);
    });
  });

  group('EntregaPagoCaja', () {
    Future<VentaCajaProvider> mostrar(WidgetTester t, String rubro) async {
      final p = crear();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: p,
                builder: (_, _) => EntregaPagoCaja(provider: p, rubro: rubro),
              ),
            ),
          ),
        ),
      );
      return p;
    }

    testWidgets('bodega: En tienda y Delivery, sin Recojo, y la pregunta', (
      t,
    ) async {
      final p = await mostrar(t, 'Bodega');

      expect(find.text('En tienda'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Recojo'), findsNothing);
      expect(find.text('¿LO PIDIÓ ANTES PARA RECOGER?'), findsOneWidget);
      for (final texto in ['No', 'WhatsApp', 'Facebook', 'Llamada', 'Otro']) {
        expect(find.text(texto), findsOneWidget);
      }

      await t.tap(find.text('WhatsApp'));
      await t.pump();
      expect(p.pedidoPor, PedidoPor.whatsapp);

      await t.tap(find.text('Delivery'));
      await t.pump();
      expect(find.text('¿LO PIDIÓ ANTES PARA RECOGER?'), findsNothing);
      expect(find.text('ZONA'), findsOneWidget);
      expect(p.pedidoPor, isNull);
    });

    testWidgets('restaurante queda igual y no pregunta', (t) async {
      await mostrar(t, 'Restaurante');

      expect(find.text('En mesa'), findsOneWidget);
      expect(find.text('Para llevar'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('¿LO PIDIÓ ANTES PARA RECOGER?'), findsNothing);
    });
  });
}
