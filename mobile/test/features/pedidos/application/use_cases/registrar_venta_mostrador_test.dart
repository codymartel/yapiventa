import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/services/validacion_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';

import '../../helpers/pedidos_de_prueba.dart';

class _RepositorioFalso implements RepositorioVentasMostrador {
  ResultadoVentaMostrador respuesta = const ResultadoVentaMostrador(
    registrada: true,
  );
  final List<SolicitudVentaMostrador> pedidas = [];
  String? negocioId;

  @override
  Future<ResultadoVentaMostrador> registrar(
    String negocioId,
    SolicitudVentaMostrador solicitud,
  ) async {
    this.negocioId = negocioId;
    pedidas.add(solicitud);
    return respuesta;
  }

  @override
  Future<List<ResumenVentasDia>> obtenerResumenes(
    String negocioId,
    String desde,
    String hasta,
  ) async => const [];

  @override
  Future<ResultadoAnulacion> anular(String negocioId, String pedidoId) async {
    return const ResultadoAnulacion();
  }
}

void main() {
  late _RepositorioFalso repo;
  late RegistrarVentaMostrador caso;

  // 350 g de queso (840) + 2 gaseosas a S/ 4,50 (900) = 1 740.
  final bodega = [
    lineaQueso(350),
    lineaSimple(cantidad: 2, precioCentavos: 450),
  ];

  setUp(() {
    repo = _RepositorioFalso();
    caso = RegistrarVentaMostrador(repo);
  });

  test('una venta en el local se calcula y se manda a registrar', () async {
    final r = await caso.ejecutar(
      negocioId: 'n1',
      idVenta: 'v1',
      lineas: bodega,
      tipoEntrega: TipoEntrega.recojo,
      enLocal: true,
      metodoPago: 'efectivo',
    );

    expect(r.registrada, isTrue);
    expect(repo.negocioId, 'n1');
    final s = repo.pedidas.single;
    expect(s.idVenta, 'v1');
    expect(s.subtotalCentavos, 1740);
    expect(s.totalCentavos, 1740);
    expect(s.enLocal, isTrue);
    expect(s.lineas.first.subtotalCentavos, 840);
  });

  test(
    'el descuento por forma de pago se calcula antes de registrar',
    () async {
      await caso.ejecutar(
        negocioId: 'n1',
        idVenta: 'v1',
        lineas: bodega,
        tipoEntrega: TipoEntrega.recojo,
        metodoPago: 'yape',
        descuento: const DescuentoPago.porcentaje(centesimas: 500),
      );

      final s = repo.pedidas.single;
      expect(s.descuentoCentavos, 87);
      expect(s.totalCentavos, 1653);
    },
  );

  test(
    'el delivery cuesta lo de la zona; en el local no cuesta nada',
    () async {
      await caso.ejecutar(
        negocioId: 'n1',
        idVenta: 'v1',
        lineas: bodega,
        tipoEntrega: TipoEntrega.delivery,
        metodoPago: 'efectivo',
        cliente: const ClientePedido(
          nombre: 'Carla',
          telefono: '987654321',
          direccion: 'Av. Larco 123',
        ),
        zona: 'Miraflores',
        deliveryCentavos: 500,
      );
      await caso.ejecutar(
        negocioId: 'n1',
        idVenta: 'v2',
        lineas: bodega,
        tipoEntrega: TipoEntrega.recojo,
        metodoPago: 'efectivo',
        deliveryCentavos: 500,
      );

      expect(repo.pedidas.first.totalCentavos, 1740 + 500);
      expect(repo.pedidas.last.deliveryCentavos, 0);
      expect(repo.pedidas.last.totalCentavos, 1740);
    },
  );

  test('si faltan datos no llama al repositorio y dice qué falta', () async {
    final r = await caso.ejecutar(
      negocioId: 'n1',
      idVenta: 'v1',
      lineas: bodega,
      tipoEntrega: TipoEntrega.delivery,
      metodoPago: 'efectivo',
    );

    expect(r.registrada, isFalse);
    expect(r.resultado, isNull);
    expect(r.invalida!.faltan, [
      CampoVenta.cliente,
      CampoVenta.telefono,
      CampoVenta.zona,
      CampoVenta.direccion,
    ]);
    expect(repo.pedidas, isEmpty);
  });

  test('sin forma de pago tampoco se intenta cobrar', () async {
    final r = await caso.ejecutar(
      negocioId: 'n1',
      idVenta: 'v1',
      lineas: bodega,
      tipoEntrega: TipoEntrega.recojo,
      metodoPago: ' ',
    );

    expect(r.invalida!.mensaje, 'Falta: forma de pago');
    expect(repo.pedidas, isEmpty);
  });

  test(
    'lo que responde el repositorio llega tal cual (falta de stock)',
    () async {
      repo.respuesta = const ResultadoVentaMostrador(
        precioCambio: true,
        totalActualCentavos: 1840,
      );

      final r = await caso.ejecutar(
        negocioId: 'n1',
        idVenta: 'v1',
        lineas: bodega,
        tipoEntrega: TipoEntrega.recojo,
        metodoPago: 'efectivo',
      );

      expect(r.registrada, isFalse);
      expect(r.resultado!.precioCambio, isTrue);
      expect(r.resultado!.totalActualCentavos, 1840);
    },
  );

  test('un delivery «cobrar al entregar» lo pasa al repositorio', () async {
    await caso.ejecutar(
      negocioId: 'n1',
      idVenta: 'v1',
      lineas: bodega,
      tipoEntrega: TipoEntrega.delivery,
      metodoPago: 'efectivo',
      cliente: const ClientePedido(
        nombre: 'Carla',
        telefono: '987654321',
        direccion: 'Av. Larco 123',
      ),
      zona: 'Miraflores',
      cobrarAlEntregar: true,
    );

    expect(repo.pedidas.single.cobrarAlEntregar, isTrue);
  });
}
