import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/caja/presentation/providers/catalogo_caja_provider.dart';
import 'package:mobile/features/caja/presentation/providers/venta_caja_provider.dart';
import 'package:mobile/features/pedidos/application/use_cases/anular_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/application/use_cases/buscar_productos_caja.dart';
import 'package:mobile/features/productos/domain/models/consulta_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_catalogo_caja.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

const _efectivo = OpcionPagoCaja(id: 'efectivo', etiqueta: 'Efectivo');
const _centro = ZonaCaja(nombre: 'Centro', costoCentavos: 300);
const _descuentos = [DescuentoStock(productoId: 'gaseosa', cantidad: 2)];

class _RepoVentas implements RepositorioVentasMostrador {
  ResultadoAnulacion anulacion = const ResultadoAnulacion();
  Object? fallaAnular;
  final List<String> anuladas = [];
  int registros = 0;

  @override
  Future<ResultadoVentaMostrador> registrar(
    String negocioId,
    SolicitudVentaMostrador solicitud,
  ) async {
    registros++;
    return const ResultadoVentaMostrador(
      registrada: true,
      pedidoId: 'v1',
      clave: 'ABC123',
      descuentos: _descuentos,
    );
  }

  @override
  Future<ResultadoAnulacion> anular(String negocioId, String pedidoId) async {
    if (fallaAnular != null) throw fallaAnular!;
    anuladas.add(pedidoId);
    return anulacion;
  }
}

class _Catalogo implements RepositorioCatalogoCaja {
  int consultas = 0;
  List<Producto> productos = [
    productoSimple(stock: 10),
    quesoPorMedida(stockBase: 1200),
    poloConModelos(),
  ];

  @override
  Future<PaginaProductos> obtenerPagina(
    String negocioId,
    ConsultaCatalogoCaja consulta, {
    CursorProductos? despuesDe,
    int limite = 20,
  }) async {
    consultas++;
    return PaginaProductos(
      productos: productos,
      ultimoCursor: null,
      hayMas: false,
    );
  }
}

void main() {
  group('cobrar con delivery', () {
    late _RepoVentas repo;

    VentaCajaProvider crear({bool conAnular = true}) => VentaCajaProvider(
      negocioId: 'n1',
      registrar: RegistrarVentaMostrador(repo),
      anular: conAnular ? AnularVentaMostrador(repo) : null,
      opcionesPago: const [_efectivo],
      zonas: const [_centro],
      generarId: () => 'id',
    );

    setUp(() => repo = _RepoVentas());

    test('en tienda basta con productos y forma de pago', () {
      final p = crear();
      expect(
        p.motivoNoCobrar,
        isNull,
        reason: 'carrito vacío: nada que avisar',
      );

      p.agregarProducto(productoSimple(), cantidad: 2);

      expect(p.puedeCobrar, isTrue);
      expect(p.motivoNoCobrar, isNull);
    });

    test('delivery incompleto no deja cobrar y dice qué falta', () {
      final p = crear();
      p.agregarProducto(productoSimple(), cantidad: 2);

      p.elegirEntrega(EntregaCaja.delivery);

      expect(p.puedeCobrar, isFalse);
      expect(p.motivoNoCobrar, 'Falta: cliente, teléfono, zona y dirección');

      p.escribirCliente('Rosa');
      p.escribirTelefono('987 654 321');
      p.elegirZona(_centro);
      expect(p.motivoNoCobrar, 'Falta: dirección');

      p.escribirDireccion('Av. Lima 123');
      expect(p.puedeCobrar, isTrue);
      expect(p.motivoNoCobrar, isNull);
    });

    test('un teléfono de pocas cifras cuenta como faltante', () {
      final p = crear();
      p.agregarProducto(productoSimple(), cantidad: 1);
      p.elegirEntrega(EntregaCaja.delivery);
      p.escribirCliente('Rosa');
      p.elegirZona(_centro);
      p.escribirDireccion('Av. Lima 123');

      p.escribirTelefono('12345');

      expect(p.puedeCobrar, isFalse);
      expect(p.motivoNoCobrar, 'Falta: teléfono');
    });

    test('volver a «en tienda» ya no pide los datos del delivery', () {
      final p = crear();
      p.agregarProducto(productoSimple(), cantidad: 1);
      p.elegirEntrega(EntregaCaja.delivery);
      expect(p.puedeCobrar, isFalse);

      p.elegirEntrega(EntregaCaja.local);

      expect(p.puedeCobrar, isTrue);
    });

    test('con las ventas bloqueadas lo dice', () {
      final p = crear();
      p.agregarProducto(productoSimple(), cantidad: 1);

      p.bloquearVentas(true);

      expect(p.puedeCobrar, isFalse);
      expect(p.motivoNoCobrar, contains('catálogo'));
    });

    test('cobrar devuelve lo que se descontó del stock', () async {
      final p = crear();
      p.agregarProducto(productoSimple(), cantidad: 2);

      final r = await p.cobrar();

      expect(r.registrada, isTrue);
      expect(r.pedidoId, 'v1');
      expect(r.descuentos.single.productoId, 'gaseosa');
      expect(r.descuentos.single.cantidad, 2);
    });
  });

  group('anular desde el aviso', () {
    late _RepoVentas repo;

    VentaCajaProvider crear({bool conAnular = true}) => VentaCajaProvider(
      negocioId: 'n1',
      registrar: RegistrarVentaMostrador(repo),
      anular: conAnular ? AnularVentaMostrador(repo) : null,
      opcionesPago: const [_efectivo],
    );

    setUp(() => repo = _RepoVentas());

    test('anula y avisa que el stock volvió', () async {
      final r = await crear().anularVenta('v1');

      expect(r.ok, isTrue);
      expect(r.mensaje, 'Venta anulada. El stock volvió.');
      expect(repo.anuladas, ['v1']);
    });

    test('si un producto ya no existe, lo dice', () async {
      repo.anulacion = const ResultadoAnulacion(sinDevolver: 1);

      final r = await crear().anularVenta('v1');

      expect(r.ok, isTrue);
      expect(r.mensaje, contains('ya no existen'));
    });

    test('ya anulada, no anulable o sin conexión: no devuelve stock', () async {
      final p = crear();

      repo.anulacion = const ResultadoAnulacion(yaAnulada: true);
      final ya = await p.anularVenta('v1');
      expect(ya.ok, isFalse);
      expect(ya.mensaje, 'Esa venta ya estaba anulada.');

      repo.fallaAnular = StateError('no se puede');
      final no = await p.anularVenta('v1');
      expect(no.ok, isFalse);
      expect(no.mensaje, contains('ya no se puede anular'));

      repo.fallaAnular = Exception('sin red');
      final red = await p.anularVenta('v1');
      expect(red.ok, isFalse);
      expect(red.mensaje, contains('Revisa tu conexión'));
    });

    test('sin el caso de uso de anular no hace nada', () async {
      final r = await crear(conAnular: false).anularVenta('v1');

      expect(r.ok, isFalse);
      expect(repo.anuladas, isEmpty);
    });
  });

  group('stock de la lista en memoria', () {
    late _Catalogo repo;
    late CatalogoCajaProvider p;

    Producto de(String id) => p.productos.firstWhere((x) => x.id == id);

    setUp(() async {
      repo = _Catalogo();
      p = CatalogoCajaProvider(
        negocioId: 'n1',
        buscar: BuscarProductosCaja(repo),
        pausa: const Duration(milliseconds: 10),
      );
      await p.iniciar();
    });

    tearDown(() => p.dispose());

    test('al cobrar resta sin volver a consultar', () {
      var avisos = 0;
      p.addListener(() => avisos++);

      p.ajustarStock(const [
        DescuentoStock(productoId: 'gaseosa', cantidad: 2),
        DescuentoStock(productoId: 'queso', cantidad: 350, enBase: true),
        DescuentoStock(
          productoId: 'polo',
          modeloId: 'luna',
          filaId: 'm',
          cantidad: 1,
        ),
      ]);

      expect(de('gaseosa').stock, 8);
      expect(de('queso').stockBase, 850);
      expect(de('polo').stock, 4, reason: 'M 3→2 y L 2: total 4');
      expect(repo.consultas, 1, reason: '0 lecturas nuevas');
      expect(avisos, 1);
    });

    test('al anular devuelve exactamente lo descontado', () {
      p.ajustarStock(_descuentos);
      expect(de('gaseosa').stock, 8);

      p.ajustarStock(_descuentos, devolver: true);

      expect(de('gaseosa').stock, 10);
      expect(repo.consultas, 1);
    });

    test('el cambio vale también para las consultas guardadas', () async {
      p.cambiarOrden(OrdenCatalogoCaja.nombre);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.consultas, 2);

      p.ajustarStock(_descuentos);
      p.cambiarOrden(OrdenCatalogoCaja.frecuentes);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.consultas, 2, reason: 'volvió de la memoria');
      expect(de('gaseosa').stock, 8);
    });

    test('nunca baja de cero y lo que no está cargado se ignora', () {
      p.ajustarStock(const [
        DescuentoStock(productoId: 'gaseosa', cantidad: 99),
        DescuentoStock(productoId: 'no-cargado', cantidad: 1),
      ]);

      expect(de('gaseosa').stock, 0);
      expect(p.productos, hasLength(3));
    });

    test('sin descuentos no avisa', () {
      var avisos = 0;
      p.addListener(() => avisos++);

      p.ajustarStock(const []);

      expect(avisos, 0);
    });
  });
}
