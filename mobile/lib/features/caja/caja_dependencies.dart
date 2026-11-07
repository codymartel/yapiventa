import 'package:mobile/features/pedidos/application/use_cases/anular_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/use_cases/obtener_informe_ventas.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';
import 'package:mobile/features/productos/application/use_cases/buscar_productos_caja.dart';
import 'package:mobile/features/productos/application/use_cases/preparar_catalogo_caja.dart';
import 'package:mobile/features/productos/data/catalogo_caja_repository.dart';
import 'package:mobile/features/productos/data/relleno_catalogo_caja_repository.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_relleno_catalogo.dart';

import 'domain/models/opciones_caja.dart';
import 'presentation/providers/catalogo_caja_provider.dart';
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
  });

  factory CajaDependencies.production() {
    return CajaDependencies.conRepositorios(
      ventas: VentasMostradorRepository(),
      catalogo: CatalogoCajaRepository(),
      relleno: RellenoCatalogoCajaRepository(),
    );
  }

  factory CajaDependencies.conRepositorios({
    required RepositorioVentasMostrador ventas,
    required RepositorioCatalogoCaja catalogo,
    required RepositorioRellenoCatalogo relleno,
  }) {
    return CajaDependencies(
      registrarVenta: RegistrarVentaMostrador(ventas),
      anularVenta: AnularVentaMostrador(ventas),
      obtenerInforme: ObtenerInformeVentas(ventas),
      buscarProductos: BuscarProductosCaja(catalogo),
      prepararCatalogo: PrepararCatalogoCaja(relleno),
    );
  }

  final RegistrarVentaMostrador registrarVenta;
  final AnularVentaMostrador anularVenta;
  final ObtenerInformeVentas obtenerInforme;
  final BuscarProductosCaja buscarProductos;
  final PrepararCatalogoCaja prepararCatalogo;

  VentaCajaProvider crearVenta(
    String negocioId, {
    List<OpcionPagoCaja> opcionesPago = const [],
    List<ZonaCaja> zonas = const [],
  }) {
    return VentaCajaProvider(
      negocioId: negocioId,
      registrar: registrarVenta,
      opcionesPago: opcionesPago,
      zonas: zonas,
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
