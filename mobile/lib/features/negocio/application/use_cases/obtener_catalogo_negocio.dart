import '../../domain/models/catalogo_negocio.dart';
import '../../domain/repositories/repositorio_catalogo_negocio.dart';

class ObtenerCatalogoNegocio {
  final RepositorioCatalogoNegocio _repository;

  const ObtenerCatalogoNegocio(this._repository);

  Future<CatalogoNegocio> call(String uid) {
    return _repository.obtenerCatalogoNegocio(uid);
  }
}
