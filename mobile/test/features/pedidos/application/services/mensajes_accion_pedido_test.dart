import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/mensajes_accion_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/cancelar_vencidos.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_pedidos.dart';

void main() {
  group('dinero', () {
    test('formatea céntimos enteros con coma', () {
      expect(MensajesAccionPedido.dinero(1840), 'S/ 18,40');
      expect(MensajesAccionPedido.dinero(805), 'S/ 8,05');
      expect(MensajesAccionPedido.dinero(0), 'S/ 0,00');
      expect(MensajesAccionPedido.dinero(99), 'S/ 0,99');
    });
  });

  group('confirmarBloqueado', () {
    test('otro vendedor ya lo tocó', () {
      final texto = MensajesAccionPedido.confirmarBloqueado(
        const ResultadoConfirmar(yaNoEsNuevo: true),
      );

      expect(texto, contains('ya no está nuevo'));
    });

    test('dice qué falta y cuánto hay', () {
      final texto = MensajesAccionPedido.confirmarBloqueado(
        const ResultadoConfirmar(
          faltas: [
            FaltaStock(nombre: 'Gaseosa Inca', pide: 2, hay: 1),
            FaltaStock(nombre: 'Queso andino', pide: 350, hay: 200),
          ],
        ),
      );

      expect(
        texto,
        'No alcanza el stock: Gaseosa Inca (pide 2, hay 1); '
        'Queso andino (pide 350, hay 200).',
      );
    });

    test('junta faltas y productos que ya no existen', () {
      final texto = MensajesAccionPedido.confirmarBloqueado(
        const ResultadoConfirmar(
          faltas: [FaltaStock(nombre: 'Papas', pide: 3, hay: 0)],
          sinProducto: ['Polo viejo'],
        ),
      );

      expect(texto, contains('Papas (pide 3, hay 0)'));
      expect(texto, contains('Ya no existe: Polo viejo.'));
    });

    test('un nombre con etiquetas se muestra tal cual, como texto', () {
      final texto = MensajesAccionPedido.confirmarBloqueado(
        const ResultadoConfirmar(sinProducto: ['<script>alert(1)</script>']),
      );

      expect(texto, 'Ya no existe: <script>alert(1)</script>.');
    });
  });

  group('confirmado', () {
    test('sin diferencia de precios', () {
      expect(
        MensajesAccionPedido.confirmado(const ResultadoConfirmar(), 1840),
        'Pedido confirmado.',
      );
    });

    test('avisa el total de hoy y qué línea cambió', () {
      final texto = MensajesAccionPedido.confirmado(
        const ResultadoConfirmar(
          totalActualCentavos: 1940,
          lineasCambiadas: ['Gaseosa Inca'],
        ),
        1840,
      );

      expect(
        texto,
        'Pedido confirmado. Con los precios de hoy el total sería S/ 19,40; '
        'el cliente vio S/ 18,40 (cambió: Gaseosa Inca).',
      );
    });
  });

  group('cancelado', () {
    test('todo devuelto', () {
      expect(MensajesAccionPedido.cancelado(0), 'Pedido cancelado.');
    });

    test('singular y plural de lo que no se pudo devolver', () {
      expect(MensajesAccionPedido.cancelado(1), contains('un producto que ya'));
      expect(
        MensajesAccionPedido.cancelado(3),
        contains('3 productos que ya no existen'),
      );
    });
  });

  group('vencidos', () {
    test('no había ninguno', () {
      expect(
        MensajesAccionPedido.vencidos(const ResultadoCancelarVencidos()),
        'No hay pedidos vencidos.',
      );
    });

    test('cuenta cancelados, omitidos y fallidos', () {
      final texto = MensajesAccionPedido.vencidos(
        const ResultadoCancelarVencidos(
          canceladas: 4,
          omitidas: 1,
          fallidas: 2,
        ),
      );

      expect(
        texto,
        'Se cancelaron 4 pedidos. 1 ya no estaba nuevo y no se tocó. '
        '2 no se pudieron cancelar: revisa tu conexión.',
      );
    });

    test('singular', () {
      expect(
        MensajesAccionPedido.vencidos(
          const ResultadoCancelarVencidos(canceladas: 1),
        ),
        'Se canceló 1 pedido.',
      );
    });
  });
}
