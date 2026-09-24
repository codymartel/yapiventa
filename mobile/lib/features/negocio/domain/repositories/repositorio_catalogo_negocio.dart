import '../models/catalogo_negocio.dart';
import '../models/catalogo_venta/catalogo_venta_persistido.dart';

abstract interface class RepositorioCatalogoNegocio {
  Future<CatalogoNegocio> obtenerCatalogoNegocio(String uid);

  /// Catálogo maestro de venta persistido en negocios/{negocioId}. Devuelve
  /// null si el documento aún no tiene `catalogoVenta` (fallback a legacy).
  Future<CatalogoVentaPersistido?> obtenerCatalogoVenta(
    String uid, {
    String? negocioId,
  });
}
