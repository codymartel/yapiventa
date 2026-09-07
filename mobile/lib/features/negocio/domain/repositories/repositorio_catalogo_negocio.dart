import '../models/catalogo_negocio.dart';

abstract interface class RepositorioCatalogoNegocio {
  Future<CatalogoNegocio> obtenerCatalogoNegocio(String uid);
}
