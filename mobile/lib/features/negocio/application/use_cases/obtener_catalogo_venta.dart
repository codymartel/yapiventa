import '../../domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../domain/repositories/repositorio_catalogo_negocio.dart';

class ObtenerCatalogoVenta {
  final RepositorioCatalogoNegocio _repository;

  const ObtenerCatalogoVenta(this._repository);

  Future<CatalogoVentaPersistido?> call(String uid, {String? negocioId}) {
    return _repository.obtenerCatalogoVenta(uid, negocioId: negocioId);
  }
}
