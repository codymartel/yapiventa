import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/texto_entrega_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido_por.dart';

/// Paso R: cómo se lee la entrega en el detalle y la lista cerrada de
/// «¿Lo pidió antes para recoger?».
void main() {
  group('PedidoPor', () {
    test('lee los cuatro valores guardados', () {
      expect(PedidoPor.desdeValor('whatsapp'), PedidoPor.whatsapp);
      expect(PedidoPor.desdeValor('facebook'), PedidoPor.facebook);
      expect(PedidoPor.desdeValor('llamada'), PedidoPor.llamada);
      expect(PedidoPor.desdeValor('otro'), PedidoPor.otro);
    });

    test('vacío, desconocido o null se lee como «No» (null)', () {
      expect(PedidoPor.desdeValor(''), isNull);
      expect(PedidoPor.desdeValor('instagram'), isNull);
      expect(PedidoPor.desdeValor('WhatsApp'), isNull);
      expect(PedidoPor.desdeValor(null), isNull);
    });
  });

  group('TextoEntregaPedido', () {
    Pedido recojo({bool enLocal = false, PedidoPor? por}) => Pedido(
      id: 'p',
      origen: OrigenPedido.mostrador,
      tipoEntrega: TipoEntrega.recojo,
      enLocal: enLocal,
      pedidoPor: por,
    );

    test('una venta en tienda pedida antes dice por dónde', () {
      expect(
        TextoEntregaPedido.de(recojo(enLocal: true, por: PedidoPor.whatsapp)),
        'Recojo en tienda · vía WhatsApp',
      );
      expect(
        TextoEntregaPedido.de(recojo(enLocal: true, por: PedidoPor.llamada)),
        'Recojo en tienda · vía Llamada',
      );
    });

    test('una venta en el local sin pedido previo dice «En el local»', () {
      expect(TextoEntregaPedido.de(recojo(enLocal: true)), 'En el local');
    });

    test('las ventas viejas de recojo y la web se leen «Recojo en tienda»', () {
      expect(TextoEntregaPedido.de(recojo()), 'Recojo en tienda');
      expect(
        TextoEntregaPedido.de(
          const Pedido(id: 'w', tipoEntrega: TipoEntrega.recojo),
        ),
        'Recojo en tienda',
      );
    });

    test('delivery: dirección, zona y costo, como antes', () {
      const conTodo = Pedido(
        id: 'd',
        cliente: ClientePedido(direccion: ' Av. Lima 123 '),
        zona: 'Centro',
        deliveryCentavos: 500,
      );
      expect(
        TextoEntregaPedido.de(conTodo),
        'Av. Lima 123 · Centro (delivery 5,00)',
      );
      expect(TextoEntregaPedido.de(const Pedido(id: 'd2')), 'Delivery');
    });
  });
}
