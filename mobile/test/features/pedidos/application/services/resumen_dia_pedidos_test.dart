import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/resumen_dia_pedidos.dart';
import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';

import '../../helpers/pedidos_de_prueba.dart';

void main() {
  test('el día es el de Lima (UTC−5): 22:00 del 30 y 00:00 del 31', () {
    // 03:00 UTC del 31 es las 22:00 del 30 en Lima.
    expect(
      ResumenDiaPedidos.claveDia(DateTime.utc(2026, 10, 31, 3)),
      '2026-10-30',
    );
    // 05:00 UTC del 31 es la medianoche del 31 en Lima.
    expect(
      ResumenDiaPedidos.claveDia(DateTime.utc(2026, 10, 31, 5)),
      '2026-10-31',
    );
  });

  test('agrupa por día, del más nuevo al más viejo, y cuenta lo entregado', () {
    final dias = ResumenDiaPedidos.agrupar([
      pedidoDe(
        [],
        id: 'a',
        estado: EstadoPedido.entregado,
        fecha: DateTime.utc(2026, 10, 31, 15),
        totalCentavos: 1840,
      ),
      pedidoDe(
        [],
        id: 'b',
        estado: EstadoPedido.entregado,
        fecha: DateTime.utc(2026, 10, 31, 20),
        totalCentavos: 3200,
      ),
      pedidoDe(
        [],
        id: 'c',
        estado: EstadoPedido.cancelado,
        fecha: DateTime.utc(2026, 10, 31, 18),
        totalCentavos: 950,
      ),
      pedidoDe(
        [],
        id: 'd',
        estado: EstadoPedido.entregado,
        fecha: DateTime.utc(2026, 10, 30, 16),
        totalCentavos: 2100,
      ),
    ]);

    expect(dias.map((d) => d.dia), ['2026-10-31', '2026-10-30']);
    final hoy = dias.first;
    expect(hoy.nEntregados, 2);
    expect(hoy.nCancelados, 1);
    expect(hoy.entregadosCentavos, 5040); // el cancelado no suma
    expect(hoy.pedidos.map((p) => p.id), ['b', 'c', 'a']);
  });

  test('un pedido sin fecha se omite y una lista vacía da cero días', () {
    expect(ResumenDiaPedidos.agrupar([pedidoDe([])]), isEmpty);
    expect(ResumenDiaPedidos.agrupar([]), isEmpty);
  });
}
