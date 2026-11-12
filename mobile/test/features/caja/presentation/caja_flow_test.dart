import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/domain/models/dia_caja.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/caja/presentation/widgets/caja_vista_tv.dart';
import 'package:mobile/features/caja/presentation/widgets/ticket_caja.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';

import '../helpers/banco_caja_flow.dart';

void main() {
  late BancoCaja banco;

  setUp(() => banco = BancoCaja());

  group('el día en vivo', () {
    testWidgets('celular: 3 números y local separado de la tienda web', (
      t,
    ) async {
      await banco.abrir(t);
      await banco.llega(t, diaDePrueba(gastos: 1000));

      expect(find.text('● En vivo'), findsOneWidget);
      expect(find.text('S/ 317,40'), findsOneWidget);
      expect(find.text('13 ventas'), findsOneWidget);
      expect(find.text('S/ 207,40'), findsOneWidget, reason: '217,40 − 10');
      expect(find.text('S/ 10,00'), findsOneWidget);
      expect(find.text('1 gasto'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('S/ 217,40'), findsOneWidget);
      expect(find.text('Tienda web'), findsOneWidget);
      expect(find.text('S/ 100,00'), findsOneWidget);
      expect(banco.dia.escuchas, 1, reason: 'escucha UN documento');
    });

    testWidgets('un día sin movimientos se lee en cero, sin errores', (
      t,
    ) async {
      await banco.abrir(t);

      expect(find.text('Cargando el día…'), findsOneWidget);
      expect(find.text('sin ventas'), findsOneWidget);
      expect(find.text('ninguno'), findsOneWidget);
    });

    testWidgets('sin conexión lo dice con texto y deja reintentar', (t) async {
      await banco.abrir(t);
      banco.dia.canal.addError(Exception('sin red'));
      await t.pumpAndSettle();

      expect(find.text('● Sin conexión'), findsOneWidget);
      expect(find.textContaining('pueden estar viejos'), findsOneWidget);

      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(banco.dia.escuchas, 2);
    });

    testWidgets('gastar antes de vender: efectivo negativo, con explicación', (
      t,
    ) async {
      await banco.abrir(t);
      await banco.llega(t, DiaCaja.vacio('2026-11-11').conGastoDePrueba(1000));

      expect(find.text('− S/ 10,00'), findsOneWidget);
      expect(find.text('salió más de lo que entró hoy'), findsOneWidget);
    });
  });

  group('vender en celular', () {
    testWidgets('agregar, ver la venta, cobrar y anular', (t) async {
      await banco.abrir(t);
      expect(find.text('Agrega productos para vender'), findsOneWidget);

      await banco.agregar(t, 'Gaseosa Inca');
      await banco.agregar(t, 'Gaseosa Inca');
      expect(find.text('Ver venta · 1 producto · S/ 7,00'), findsOneWidget);

      await t.tap(find.textContaining('Ver venta'));
      await t.pumpAndSettle();
      expect(find.text('En tienda'), findsOneWidget);
      expect(find.text('2 × 3,50'), findsOneWidget);

      await t.tap(find.text('Cobrar S/ 7,00'));
      await t.pumpAndSettle();

      expect(banco.ventas.cobradas.single.totalCentavos, 700);
      expect(banco.ventas.cobradas.single.metodoPago, 'efectivo');
      expect(find.text('Venta registrada · S/ 7,00'), findsOneWidget);
      expect(find.text('Agrega productos para vender'), findsOneWidget);
      expect(banco.catalogo.consultas, 1, reason: 'el stock bajó sin releer');

      await t.tap(find.text('Anular'));
      await t.pumpAndSettle();

      expect(banco.ventas.anuladas, ['v1']);
      expect(find.text('Venta anulada. El stock volvió.'), findsOneWidget);
      expect(banco.catalogo.consultas, 1);
    });

    testWidgets('las formas de pago y las zonas son las del negocio', (
      t,
    ) async {
      await banco.abrir(
        t,
        pagos: const [efectivoDePrueba, OpcionPagoCajaDePrueba.tarjeta],
        zonas: const [],
      );
      await banco.agregar(t, 'Gaseosa Inca');
      await t.tap(find.textContaining('Ver venta'));
      await t.pumpAndSettle();

      expect(find.text('Tarjeta BCP'), findsOneWidget);
      expect(find.text('Yape'), findsNothing);

      await t.tap(find.text('Delivery'));
      await t.pumpAndSettle();
      expect(find.textContaining('Aún no tienes zonas'), findsOneWidget);
    });

    testWidgets('delivery incompleto apaga «Cobrar» y dice qué falta', (
      t,
    ) async {
      await banco.abrir(t);
      await banco.agregar(t, 'Gaseosa Inca');
      await t.tap(find.textContaining('Ver venta'));
      await t.pumpAndSettle();

      await t.tap(find.text('Delivery'));
      await t.pumpAndSettle();
      expect(
        find.text('Falta: cliente, teléfono, zona y dirección'),
        findsOneWidget,
      );

      await t.tap(find.text('Centro · 3,00'));
      await t.enterText(banco.campoHoja(0), 'Rosa');
      await t.enterText(banco.campoHoja(1), '987654321');
      await t.pumpAndSettle();
      expect(find.text('Falta: dirección'), findsOneWidget);
      await t.tap(find.text('Cobrar S/ 6,50'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(banco.ventas.cobradas, isEmpty);

      await t.enterText(banco.campoHoja(2), 'Av. Lima 123');
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Cobrar S/ 6,50'));
      await t.tap(find.text('Cobrar S/ 6,50'));
      await t.pumpAndSettle();

      final v = banco.ventas.cobradas.single;
      expect(v.tipoEntrega, TipoEntrega.delivery);
      expect(v.cliente.direccion, 'Av. Lima 123');
      expect(v.deliveryCentavos, 300);
      expect(
        find.text('Venta registrada · S/ 6,50 · Sigue en Pedidos'),
        findsOneWidget,
      );
      expect(find.text('Anular'), findsNothing, reason: 'sigue en Pedidos');
    });

    testWidgets('si cobrar falla lo avisa y conserva la venta', (t) async {
      await banco.abrir(t);
      await banco.agregar(t, 'Gaseosa Inca');
      banco.ventas.falla = Exception('sin red');
      await t.tap(find.textContaining('Ver venta'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cobrar S/ 3,50'));
      await t.pumpAndSettle();

      expect(find.textContaining('no se cobrará dos veces'), findsOneWidget);
      expect(find.text('Ver venta · 1 producto · S/ 3,50'), findsOneWidget);
    });

    testWidgets('restaurante usa sus propias palabras de entrega', (t) async {
      await banco.abrir(t, rubro: 'Restaurante');
      await banco.agregar(t, 'Gaseosa Inca');
      await t.tap(find.textContaining('Ver venta'));
      await t.pumpAndSettle();

      expect(find.text('En mesa'), findsOneWidget);
      expect(find.text('Para llevar'), findsOneWidget);
      expect(find.text('Mesa o nombre (opcional)'), findsOneWidget);
    });
  });

  group('las dos familias de pantalla', () {
    testWidgets('tableta: la venta está fija al costado', (t) async {
      await banco.abrir(t, ancho: 820, alto: 1100);

      expect(find.byType(TicketCajaPanel), findsOneWidget);
      expect(find.textContaining('Ver venta'), findsNothing);

      await banco.agregar(t, 'Gaseosa Inca');
      await t.tap(find.text('Cobrar S/ 3,50'));
      await t.pumpAndSettle();
      expect(banco.ventas.cobradas, hasLength(1));
    });

    testWidgets('celular de lado: lista y venta lado a lado, día en una fila', (
      t,
    ) async {
      await banco.abrir(t, ancho: 812, alto: 375);
      await banco.llega(t, diaDePrueba(gastos: 1000));

      expect(find.byType(TicketCajaPanel), findsOneWidget);
      expect(find.textContaining('Hoy '), findsOneWidget);
      expect(find.text('13 ventas'), findsNothing, reason: 'fila compacta');
    });

    testWidgets('PC: tablero de 6 números con web, local y lo que queda', (
      t,
    ) async {
      await banco.abrir(t, ancho: 1280, alto: 800);
      await banco.llega(t, diaDePrueba(gastos: 1000));

      expect(find.byType(TicketCajaPanel), findsOneWidget);
      expect(find.text('Tienda web'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Queda del día'), findsOneWidget);
      expect(find.text('S/ 307,40'), findsOneWidget);
    });

    testWidgets('laptop bajita: los números pasan a una fila delgada', (
      t,
    ) async {
      await banco.abrir(t, ancho: 1280, alto: 460);
      await banco.llega(t, diaDePrueba(gastos: 1000));

      expect(find.byType(TicketCajaPanel), findsOneWidget);
      expect(find.text('Queda del día'), findsNothing);
      expect(find.textContaining('Queda '), findsOneWidget);
    });

    testWidgets('TV: solo se mira, sin cobrar ni gasto', (t) async {
      await banco.abrir(t, ancho: 1920, alto: 1080);
      await banco.llega(t, diaDePrueba(gastos: 1000));

      expect(find.byType(CajaVistaTv), findsOneWidget);
      expect(find.text('Gasto'), findsNothing);
      expect(find.byType(TicketCajaPanel), findsNothing);
      expect(find.text('Comida S/ 10,00'), findsOneWidget);
    });

    for (final (nombre, ancho, alto) in const [
      ('celular chico', 320.0, 568.0),
      ('celular', 390.0, 780.0),
      ('celular de lado', 812.0, 375.0),
      ('celular chico de lado', 568.0, 320.0),
      ('tableta vertical', 768.0, 1024.0),
      ('tableta horizontal', 1024.0, 768.0),
      ('laptop', 1366.0, 768.0),
      ('laptop bajita', 1280.0, 460.0),
      ('TV', 1920.0, 1080.0),
    ]) {
      testWidgets('$nombre ($ancho × $alto): nada se desborda', (t) async {
        await banco.abrir(t, ancho: ancho, alto: alto);
        await banco.llega(t, diaDePrueba(gastos: 1000));

        expect(t.takeException(), isNull);
      });
    }
  });
}

/// Una forma de pago propia de un negocio (no es de las 4 de siempre).
abstract final class OpcionPagoCajaDePrueba {
  static const tarjeta = OpcionPagoCaja(id: 'tarjeta', etiqueta: 'Tarjeta BCP');
}

extension on DiaCaja {
  DiaCaja conGastoDePrueba(int centavos) => DiaCaja(
    ventas: ventas,
    gastos: GastosDia(
      totalCentavos: centavos,
      cantidad: 1,
      porPago: {'efectivo': centavos},
    ),
  );
}
