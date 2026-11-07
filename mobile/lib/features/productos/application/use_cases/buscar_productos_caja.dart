import '../../domain/models/consulta_catalogo_caja.dart';
import '../../domain/models/pagina_productos.dart';
import '../../domain/repositories/repositorio_catalogo_caja.dart';

/// Pide al catálogo de Caja una página de 20 productos. El tamaño de la página
/// vive aquí (una sola vez) para que ninguna pantalla pida más de la cuenta.
class BuscarProductosCaja {
  const BuscarProductosCaja(this._repositorio);

  static const int tamanoPagina = 20;

  final RepositorioCatalogoCaja _repositorio;

  Future<PaginaProductos> call({
    required String negocioId,
    ConsultaCatalogoCaja consulta = const ConsultaCatalogoCaja(),
    CursorProductos? despuesDe,
  }) {
    return _repositorio.obtenerPagina(
      negocioId,
      consulta,
      despuesDe: despuesDe,
      limite: tamanoPagina,
    );
  }
}
