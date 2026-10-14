import 'application/use_cases/obtener_catalogo_negocio.dart';
import 'application/use_cases/obtener_catalogo_venta.dart';
import 'data/negocio_repository.dart';

class CatalogoNegocioDependencies {
  final ObtenerCatalogoNegocio obtenerCatalogoNegocio;

  /// Catálogo maestro de venta. Es NULLABLE a propósito: los mocks de tests
  /// antiguos no lo definen y el provider degrada sin él (catálogo de venta
  /// simplemente no disponible). La producción siempre lo inyecta.
  final ObtenerCatalogoVenta? obtenerCatalogoVenta;

  const CatalogoNegocioDependencies({
    required this.obtenerCatalogoNegocio,
    this.obtenerCatalogoVenta,
  });

  factory CatalogoNegocioDependencies.production() {
    final repository = NegocioRepository();
    return CatalogoNegocioDependencies(
      obtenerCatalogoNegocio: ObtenerCatalogoNegocio(repository),
      obtenerCatalogoVenta: ObtenerCatalogoVenta(repository),
    );
  }
}
