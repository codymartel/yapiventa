import 'package:mobile/features/pedidos/application/use_cases/anular_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/use_cases/obtener_informe_ventas.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/data/resumenes_ventas_repository.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_resumenes_ventas.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/application/use_cases/buscar_productos_caja.dart';
import 'package:mobile/features/productos/application/use_cases/preparar_catalogo_caja.dart';
import 'package:mobile/features/productos/data/catalogo_caja_repository.dart';
import 'package:mobile/features/productos/data/relleno_catalogo_caja_repository.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_relleno_catalogo.dart';

import 'application/use_cases/gastos_caja.dart';
import 'data/dia_caja_repository.dart';
import 'data/gastos_caja_repository.dart';
import 'domain/models/opciones_caja.dart';
import 'domain/repositories/repositorios_gastos_caja.dart';
import 'presentation/providers/catalogo_caja_provider.dart';
import 'presentation/providers/dia_caja_provider.dart';
import 'presentation/providers/gasto_caja_provider.dart';
import 'presentation/providers/informes_caja_provider.dart';
import 'presentation/providers/preparacion_catalogo_provider.dart';
import 'presentation/providers/venta_caja_provider.dart';

/// Arma, en un solo lugar, los repositorios y casos de uso de Caja (igual que
/// `PedidosDependencies`). La pantalla solo le pide los providers.
class CajaDependencies {
  const CajaDependencies({
    required this.registrarVenta,
    required this.anularVenta,
    required this.obtenerInforme,
    required this.buscarProductos,
    required this.prepararCatalogo,
    required this.registrarGasto,
    required this.anularGasto,
    required this.diaCaja,
  });

  factory CajaDependencies.production() {
    return CajaDependencies.conRepositorios(
      ventas: VentasMostradorRepository(),
      resumenes: ResumenesVentasRepository(),
      catalogo: CatalogoCajaRepository(),
      relleno: RellenoCatalogoCajaRepository(),
      gastos: GastosCajaRepository(),
      dia: DiaCajaRepository(),
    );
  }

  factory CajaDependencies.conRepositorios({
    required RepositorioVentasMostrador ventas,
    required RepositorioResumenesVentas resumenes,
    required RepositorioCatalogoCaja catalogo,
    required RepositorioRellenoCatalogo relleno,
    required RepositorioGastosCaja gastos,
    required RepositorioDiaCaja dia,
  }) {
    return CajaDependencies(
      registrarVenta: RegistrarVentaMostrador(ventas),
      anularVenta: AnularVentaMostrador(ventas),
      obtenerInforme: ObtenerInformeVentas(resumenes),
      buscarProductos: BuscarProductosCaja(catalogo),
      prepararCatalogo: PrepararCatalogoCaja(relleno),
      registrarGasto: RegistrarGastoCaja(gastos),
      anularGasto: AnularGastoCaja(gastos),
      diaCaja: dia,
    );
  }

  final RegistrarVentaMostrador registrarVenta;
  final AnularVentaMostrador anularVenta;
  final ObtenerInformeVentas obtenerInforme;
  final BuscarProductosCaja buscarProductos;
  final PrepararCatalogoCaja prepararCatalogo;
  final RegistrarGastoCaja registrarGasto;
  final AnularGastoCaja anularGasto;
  final RepositorioDiaCaja diaCaja;

  VentaCajaProvider crearVenta(
    String negocioId, {
    List<OpcionPagoCaja> opcionesPago = const [],
    List<ZonaCaja> zonas = const [],
  }) {
    return VentaCajaProvider(
      negocioId: negocioId,
      registrar: registrarVenta,
      anular: anularVenta,
      opcionesPago: opcionesPago,
      zonas: zonas,
    );
  }

  GastoCajaProvider crearGasto(
    String negocioId, {
    List<OpcionPagoCaja> opcionesPago = const [],
  }) {
    return GastoCajaProvider(
      negocioId: negocioId,
      registrar: registrarGasto,
      anular: anularGasto,
      opcionesPago: opcionesPago,
    );
  }

  DiaCajaProvider crearDia(String negocioId, {DateTime Function()? reloj}) {
    return DiaCajaProvider(
      negocioId: negocioId,
      repositorio: diaCaja,
      reloj: reloj,
    );
  }

  CatalogoCajaProvider crearCatalogo(String negocioId) {
    return CatalogoCajaProvider(negocioId: negocioId, buscar: buscarProductos);
  }

  PreparacionCatalogoProvider crearPreparacion(String negocioId) {
    return PreparacionCatalogoProvider(
      negocioId: negocioId,
      preparar: prepararCatalogo,
    );
  }

  InformesCajaProvider crearInformes(
    String negocioId, {
    DateTime Function()? reloj,
  }) {
    return InformesCajaProvider(
      negocioId: negocioId,
      obtener: obtenerInforme,
      reloj: reloj,
    );
  }
}
