import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';
import 'package:mobile/features/pedidos/application/services/enlace_whatsapp.dart';
import 'package:mobile/features/pedidos/application/services/texto_lineas_pedido.dart';
import 'package:mobile/features/pedidos/application/services/tiempo_transcurrido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';

import '../../helpers/pedidos_de_prueba.dart';

void main() {
  group('TiempoTranscurrido', () {
    final ahora = DateTime.utc(2026, 11, 5, 20);

    test('minutos, horas con resto, horas justas y días', () {
      expect(
        TiempoTranscurrido.hace(
          ahora.subtract(const Duration(minutes: 4)),
          ahora,
        ),
        'hace 4 min',
      );
      expect(
        TiempoTranscurrido.hace(
          ahora.subtract(const Duration(hours: 2, minutes: 40)),
          ahora,
        ),
        'hace 2 h 40 min',
      );
      expect(
        TiempoTranscurrido.hace(
          ahora.subtract(const Duration(hours: 13)),
          ahora,
        ),
        'hace 13 h',
      );
      expect(
        TiempoTranscurrido.hace(
          ahora.subtract(const Duration(hours: 50)),
          ahora,
        ),
        'hace 2 d',
      );
    });

    test('menos de un minuto, sin fecha o en el futuro: ahora', () {
      expect(
        TiempoTranscurrido.hace(
          ahora.subtract(const Duration(seconds: 30)),
          ahora,
        ),
        'ahora',
      );
      expect(TiempoTranscurrido.hace(null, ahora), 'ahora');
      expect(
        TiempoTranscurrido.hace(ahora.add(const Duration(minutes: 5)), ahora),
        'ahora',
      );
    });
  });

  group('EnlaceWhatsapp', () {
    test('un celular de Perú con espacios lleva el prefijo 51', () {
      final url = EnlaceWhatsapp.construir('987 654 321');

      expect(url.toString(), 'https://wa.me/51987654321');
    });

    test('quita símbolos y no agrega prefijo si ya lo trae', () {
      final url = EnlaceWhatsapp.construir('+51 (987) 654-321');

      expect(url.toString(), 'https://wa.me/51987654321');
    });

    test('usa el país del negocio', () {
      final mexico = paisesLatam.firstWhere((p) => p.nombre == 'México');

      final url = EnlaceWhatsapp.construir('55 1234 5678', pais: mexico);

      expect(url.toString(), 'https://wa.me/525512345678');
    });

    test('vacío o demasiado corto no da enlace', () {
      expect(EnlaceWhatsapp.construir(''), isNull);
      expect(EnlaceWhatsapp.construir('abc'), isNull);
      expect(EnlaceWhatsapp.construir('12345'), isNull);
    });

    test(
      'texto con símbolos peligrosos no entra a la URL como texto libre',
      () {
        final url = EnlaceWhatsapp.construir(
          '987654321<script>alert(1)</script>',
        );

        expect(url.toString(), startsWith('https://wa.me/'));
        expect(url.toString(), isNot(contains('<')));
        expect(url!.host, 'wa.me');
      },
    );

    test('el mensaje se codifica, no se concatena', () {
      final url = EnlaceWhatsapp.construir(
        '987654321',
        mensaje: 'Hola & "bienvenido" #7GHMHF',
      );

      expect(url!.queryParameters['text'], 'Hola & "bienvenido" #7GHMHF');
      expect(url.toString(), isNot(contains('"')));
      expect(url.host, 'wa.me');
    });
  });

  group('TextoLineasPedido', () {
    test('se cuenta, por medida y con modelo', () {
      expect(
        TextoLineasPedido.linea(lineaSimple(cantidad: 2)),
        '2× Gaseosa Inca',
      );
      expect(TextoLineasPedido.linea(lineaQueso(350)), '350 Queso andino');
      expect(
        TextoLineasPedido.linea(
          const LineaPedido(
            productoId: 'polo',
            nombre: 'Polo básico',
            etiqueta: 'Luna · M',
            cantidad: 1,
            precioCentavos: 5000,
          ),
        ),
        '1× Polo básico (Luna · M)',
      );
    });

    test('cantidad corta para el detalle', () {
      expect(TextoLineasPedido.cantidad(lineaQueso(350)), '350');
      expect(TextoLineasPedido.cantidad(lineaSimple(cantidad: 2)), '×2');
    });

    test('el resumen corta en 2 y dice cuántas más hay', () {
      final lineas = [
        lineaQueso(350),
        lineaSimple(cantidad: 2),
        lineaSimple(productoId: 'x', nombre: 'Arroz'),
      ];

      expect(
        TextoLineasPedido.resumen(lineas),
        '350 Queso andino, 2× Gaseosa Inca y 1 más',
      );
      expect(
        TextoLineasPedido.resumen(lineas.take(2).toList()),
        '350 Queso andino, 2× Gaseosa Inca',
      );
      expect(TextoLineasPedido.resumen(const []), 'Sin productos');
    });
  });
}
