import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/validacion_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';

import '../../helpers/pedidos_de_prueba.dart';

void main() {
  final lineas = [lineaSimple(cantidad: 2)];

  ResultadoValidacionVenta validar({
    TipoEntrega entrega = TipoEntrega.recojo,
    String pago = 'efectivo',
    ClientePedido cliente = const ClientePedido(),
    String zona = '',
    String nota = '',
    bool conProductos = true,
  }) {
    return ValidacionVentaMostrador.validar(
      lineas: conProductos ? lineas : const [],
      metodoPago: pago,
      tipoEntrega: entrega,
      cliente: cliente,
      zona: zona,
      nota: nota,
    );
  }

  group('en el local y recojo', () {
    test('basta con productos y forma de pago: el cliente es opcional', () {
      expect(validar().ok, isTrue);
      expect(
        validar(cliente: const ClientePedido(nombre: 'Mesa 4')).ok,
        isTrue,
      );
    });

    test('sin forma de pago falta eso', () {
      final r = validar(pago: '  ');

      expect(r.faltan, [CampoVenta.formaPago]);
      expect(r.mensaje, 'Falta: forma de pago');
    });

    test('sin productos (o todos en cantidad 0) falta eso', () {
      expect(validar(conProductos: false).faltan, [CampoVenta.productos]);
    });
  });

  group('delivery', () {
    const completo = ClientePedido(
      nombre: 'Carla',
      telefono: '987 654 321',
      direccion: 'Av. Larco 123',
    );

    test('con cliente, teléfono, zona y dirección está listo', () {
      final r = validar(
        entrega: TipoEntrega.delivery,
        cliente: completo,
        zona: 'Miraflores',
      );

      expect(r.ok, isTrue);
    });

    test('con solo el nombre faltan teléfono, zona y dirección', () {
      final r = validar(
        entrega: TipoEntrega.delivery,
        cliente: const ClientePedido(nombre: 'Carla'),
      );

      expect(r.faltan, [
        CampoVenta.telefono,
        CampoVenta.zona,
        CampoVenta.direccion,
      ]);
      expect(r.mensaje, 'Falta: teléfono, zona y dirección');
    });

    test('sin nada pide los cuatro, con «y» antes del último', () {
      final r = validar(entrega: TipoEntrega.delivery);

      expect(r.mensaje, 'Falta: cliente, teléfono, zona y dirección');
    });

    test('un teléfono con menos de 7 cifras no vale', () {
      final r = validar(
        entrega: TipoEntrega.delivery,
        cliente: const ClientePedido(
          nombre: 'Carla',
          telefono: '12-34',
          direccion: 'Av. Larco 123',
        ),
        zona: 'Miraflores',
      );

      expect(r.faltan, [CampoVenta.telefono]);
    });

    test('dos faltas se unen con «y»: cliente y teléfono', () {
      final r = validar(
        entrega: TipoEntrega.delivery,
        cliente: const ClientePedido(direccion: 'Av. Larco 123'),
        zona: 'Miraflores',
      );

      expect(r.mensaje, 'Falta: cliente y teléfono');
    });
  });

  group('límites de tamaño (los mismos de las reglas de Firestore)', () {
    test('una nota de 501 letras es muy larga; de 500 vale', () {
      expect(validar(nota: 'a' * 500).ok, isTrue);

      final r = validar(nota: 'a' * 501);

      expect(r.muyLargos, [CampoVenta.nota]);
      expect(r.mensaje, 'Es muy largo: nota');
    });

    test('nombre de más de 80 y dirección de más de 200', () {
      final r = validar(
        entrega: TipoEntrega.delivery,
        cliente: ClientePedido(
          nombre: 'a' * 81,
          telefono: '987654321',
          direccion: 'b' * 201,
        ),
        zona: 'z' * 61,
      );

      expect(r.muyLargos, [
        CampoVenta.cliente,
        CampoVenta.direccion,
        CampoVenta.zona,
      ]);
    });

    test('faltas y excesos se muestran juntos', () {
      final r = validar(pago: '', nota: 'a' * 501);

      expect(r.mensaje, 'Falta: forma de pago. Es muy largo: nota');
    });
  });
}
