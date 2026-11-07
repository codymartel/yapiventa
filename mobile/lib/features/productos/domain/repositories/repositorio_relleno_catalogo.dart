/// Lo que pasó al preparar el catálogo de un negocio para Caja.
class ResultadoRelleno {
  const ResultadoRelleno({
    this.actualizados = 0,
    this.yaCompletos = 0,
    this.omitidos = 0,
    this.demasiados = false,
    this.total = 0,
  });

  /// Productos a los que se les escribieron los campos que faltaban.
  final int actualizados;

  /// Productos que ya estaban completos (no se tocaron).
  final int yaCompletos;

  /// Documentos que no se pudieron leer como producto (sin nombre o sin
  /// negocio): no se tocaron.
  final int omitidos;

  /// El negocio pasa del tope de productos: no se escribió NADA.
  final bool demasiados;

  /// Documentos leídos.
  final int total;
}

/// Prepara los productos viejos para el catálogo de Caja. La implementación
/// vive en `data/`.
abstract class RepositorioRellenoCatalogo {
  /// ¿Ya se preparó el catálogo de este negocio? Lee 1 documento (el negocio).
  Future<bool> catalogoListo(String negocioId);

  /// Lee los productos y escribe SOLO los campos que faltan; al final marca el
  /// catálogo como listo. Es seguro repetirlo. Lecturas: tantas como
  /// productos; escrituras: una por producto incompleto más la marca.
  Future<ResultadoRelleno> rellenar(String negocioId);
}
