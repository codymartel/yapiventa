import 'application/use_cases/obtener_catalogo_negocio.dart';
import 'data/negocio_repository.dart';

class CatalogoNegocioDependencies {
  final ObtenerCatalogoNegocio obtenerCatalogoNegocio;

  const CatalogoNegocioDependencies({required this.obtenerCatalogoNegocio});

  factory CatalogoNegocioDependencies.production() {
    final repository = NegocioRepository();
    return CatalogoNegocioDependencies(
      obtenerCatalogoNegocio: ObtenerCatalogoNegocio(repository),
    );
  }
}
