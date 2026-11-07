import '../models/consulta_catalogo_caja.dart';
import '../models/pagina_productos.dart';

/// El catálogo que ve el cajero en Caja. La implementación vive en `data/`.
abstract class RepositorioCatalogoCaja {
  /// Una página de productos DISPONIBLES que cumplen la consulta. Lee como
  /// máximo [limite] + 1 documentos (el último solo para saber si hay más).
  Future<PaginaProductos> obtenerPagina(
    String negocioId,
    ConsultaCatalogoCaja consulta, {
    CursorProductos? despuesDe,
    int limite = 20,
  });
}
