import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/caja_dependencies.dart';
import 'package:mobile/features/caja/domain/models/dia_caja.dart';
import 'package:mobile/features/caja/domain/models/gasto_caja.dart';
import 'package:mobile/features/caja/domain/models/opciones_caja.dart';
import 'package:mobile/features/caja/domain/repositories/repositorios_gastos_caja.dart';
import 'package:mobile/features/caja/presentation/widgets/caja_flow.dart';
import 'package:mobile/features/caja/presentation/widgets/hoja_caja.dart';
import 'package:mobile/features/pedidos/domain/models/contadores_dia.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_stock.dart';
import 'package:mobile/features/pedidos/domain/models/resumen_ventas_dia.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_resumenes_ventas.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/domain/models/consulta_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_relleno_catalogo.dart';

import '../../pedidos/helpers/pedidos_de_prueba.dart';

// Banco de pruebas de la pantalla de Caja: repositorios falsos (sin
// Firestore) y cómo abrirla con un tamaño de pantalla dado.

const efectivoDePrueba = OpcionPagoCaja(id: 'efectivo', etiqueta: 'Efectivo');
const yapeDePrueba = OpcionPagoCaja(id: 'yape', etiqueta: 'Yape');
const centroDePrueba = ZonaCaja(nombre: 'Centro', costoCentavos: 300);

class VentasFalsas implements RepositorioVentasMostrador {
  final List<SolicitudVentaMostrador> cobradas = [];
  final List<String> anuladas = [];
  Object? falla;

  @override
  Future<ResultadoVentaMostrador> registrar(
    String negocioId,
    SolicitudVentaMostrador solicitud,
  ) async {
    if (falla != null) throw falla!;
    cobradas.add(solicitud);
    return ResultadoVentaMostrador(
      registrada: true,
      pedidoId: 'v${cobradas.length}',
      clave: 'ABC123',
      descuentos: [
        for (final l in solicitud.lineas)
          DescuentoStock(productoId: l.productoId, cantidad: l.cantidad),
      ],
    );
  }

  @override
  Future<ResultadoAnulacion> anular(String negocioId, String pedidoId) async {
    anuladas.add(pedidoId);
    return const ResultadoAnulacion();
  }
}

class CatalogoFalso implements RepositorioCatalogoCaja {
  int consultas = 0;
  List<Producto> productos = [
    productoSimple(stock: 12),
    productoSimple(id: 'arroz', nombre: 'Arroz costeño', precioCentavos: 420),
    productoSimple(id: 'leche', nombre: 'Leche gloria', precioCentavos: 480),
    productoSimple(id: 'atun', nombre: 'Atún real', precioCentavos: 650),
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
      productos: List.of(productos),
      ultimoCursor: null,
      hayMas: false,
    );
  }
}

class RellenoListo implements RepositorioRellenoCatalogo {
  @override
  Future<bool> catalogoListo(String negocioId) async => true;

  @override
  Future<ResultadoRelleno> rellenar(String negocioId) async =>
      const ResultadoRelleno();
}

class ResumenesVacios implements RepositorioResumenesVentas {
  @override
  Future<List<ResumenVentasDia>> obtenerResumenes(
    String negocioId,
    String desde,
    String hasta,
  ) async => const [];
}

class GastosFalsos implements RepositorioGastosCaja, RepositorioGastosDelDia {
  final List<GastoCaja> guardados = [];
  final List<String> anulados = [];

  /// Correcciones pedidas: (id del viejo, gasto correcto).
  final List<(String, GastoCaja)> corregidos = [];

  /// Lo que devuelve «Gastos de hoy».
  List<GastoCaja> deHoy = [];
  int lecturasDeHoy = 0;
  Object? falla;

  @override
  Future<bool> registrar(String negocioId, GastoCaja gasto) async {
    if (falla != null) throw falla!;
    guardados.add(gasto);
    return true;
  }

  @override
  Future<ResultadoAnularGasto> anular(String negocioId, String gastoId) async {
    anulados.add(gastoId);
    return const ResultadoAnularGasto();
  }

  @override
  Future<ResultadoCorregirGasto> corregir(
    String negocioId, {
    required String viejoId,
    required GastoCaja correcto,
  }) async {
    if (falla != null) throw falla!;
    corregidos.add((viejoId, correcto));
    return ResultadoCorregirGasto.corregido;
  }

  @override
  Future<List<GastoCaja>> delDia(
    String negocioId,
    String dia, {
    int limite = 20,
  }) async {
    lecturasDeHoy++;
    if (falla != null) throw falla!;
    return deHoy.where((g) => g.dia == dia).take(limite).toList();
  }
}

class DiaFalso implements RepositorioDiaCaja {
  final canal = StreamController<DiaCaja>.broadcast();
  int escuchas = 0;

  @override
  Stream<DiaCaja> escuchar(String negocioId, String dia) {
    escuchas++;
    return canal.stream;
  }
}

/// Un día con S/ 317,40 vendidos (S/ 217,40 en el local, todo en efectivo, y
/// S/ 100,00 de la tienda web por Yape) y, si se pide, S/ 10,00 de gasto.
DiaCaja diaDePrueba({int gastos = 0}) {
  return DiaCaja(
    ventas: const ResumenVentasDia(
      dia: '2026-11-11',
      ventasCentavos: 31740,
      entregados: 13,
      contadores: ContadoresDia(
        mostradorCentavos: 21740,
        mostrador: 9,
        porPago: {'efectivo': 21740, 'yape': 10000},
      ),
    ),
    gastos: gastos <= 0
        ? GastosDia.vacio
        : GastosDia(
            totalCentavos: gastos,
            cantidad: 1,
            porPago: {'efectivo': gastos},
            porMotivo: {'comida': gastos},
          ),
  );
}

class BancoCaja {
  final ventas = VentasFalsas();
  final catalogo = CatalogoFalso();
  final gastos = GastosFalsos();
  final dia = DiaFalso();

  /// Las dependencias de Caja armadas con los repositorios falsos.
  late final CajaDependencies dependencias = CajaDependencies.conRepositorios(
    ventas: ventas,
    resumenes: ResumenesVacios(),
    catalogo: catalogo,
    relleno: RellenoListo(),
    gastos: gastos,
    dia: dia,
    gastosDelDia: gastos,
    // El mismo día que el reloj de Caja: antes el gasto usaba la hora real y
    // la prueba fallaba cualquier día que no fuera el 2026-11-11.
    reloj: () => DateTime.utc(2026, 11, 11, 17),
  );

  /// Abre Caja en una pantalla de [ancho] × [alto]. [teclado] simula el
  /// teclado en pantalla abierto (le quita ese alto por abajo).
  Future<void> abrir(
    WidgetTester tester, {
    double ancho = 390,
    double alto = 780,
    String rubro = 'Bodega',
    List<OpcionPagoCaja> pagos = const [efectivoDePrueba, yapeDePrueba],
    List<ZonaCaja> zonas = const [centroDePrueba],
  }) async {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(dia.canal.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SafeArea(
            child: CajaFlow(
              negocioId: 'n1',
              rubro: rubro,
              dependencias: dependencias,
              opcionesPago: pagos,
              zonas: zonas,
              reloj: () => DateTime.utc(2026, 11, 11, 17),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Llega un cambio del día (como cuando Firestore avisa).
  Future<void> llega(WidgetTester tester, DiaCaja d) async {
    dia.canal.add(d);
    await tester.pumpAndSettle();
  }

  /// El campo de texto número [i] de la hoja abierta (venta, gasto). La
  /// lista de atrás tiene su propio buscador: no cuenta.
  Finder campoHoja(int i) => find
      .descendant(
        of: find.byType(MarcoHojaCaja),
        matching: find.byType(TextField),
      )
      .at(i);

  int get camposHoja => find
      .descendant(
        of: find.byType(MarcoHojaCaja),
        matching: find.byType(TextField),
      )
      .evaluate()
      .length;

  /// Abre o cierra el teclado en pantalla.
  Future<void> teclado(WidgetTester tester, double alto) async {
    tester.view.viewInsets = FakeViewPadding(bottom: alto);
    await tester.pumpAndSettle();
  }

  /// Toca un producto de la lista y lo agrega con «Agregar y seguir».
  Future<void> agregar(WidgetTester tester, String nombre) async {
    await tester.tap(find.text(nombre).first);
    await tester.pumpAndSettle();
    // En pantallas bajitas la hoja del producto se desliza: el botón puede
    // quedar más abajo.
    await tester.ensureVisible(find.text('Agregar y seguir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar y seguir'));
    await tester.pumpAndSettle();
  }
}
