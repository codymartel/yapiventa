import '../../domain/repositories/repositorio_relleno_catalogo.dart';

/// Deja listo el catálogo de un negocio para Caja (una sola vez).
///
/// La pantalla llama primero a [hacePrecisoPreparar]; si es true, muestra un
/// aviso claro («se leerán y actualizarán tus productos una vez») y SOLO si el
/// vendedor acepta llama a [preparar]. Nada se escribe sin ese «sí».
class PrepararCatalogoCaja {
  const PrepararCatalogoCaja(this._repositorio);

  final RepositorioRellenoCatalogo _repositorio;

  /// true si todavía no se preparó. Lee 1 documento (el negocio).
  Future<bool> hacePrecisoPreparar(String negocioId) async {
    return !await _repositorio.catalogoListo(negocioId);
  }

  /// Lee los productos y completa los campos que faltan. Seguro de repetir.
  Future<ResultadoRelleno> preparar(String negocioId) {
    return _repositorio.rellenar(negocioId);
  }
}
