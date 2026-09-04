// ═════════════════════════════════════════════════════════════════════════
// IdentidadNegocio
// ═════════════════════════════════════════════════════════════════════════
// Migración directa de tu `data class IdentidadNegocio` (urlLogo,
// urlFachada). Mismo agregado que en Producto: se preparan campos para
// el public_id de Cloudinary de cada imagen, para poder borrarlas en el
// futuro sin tener que rastrearlas.
// ═════════════════════════════════════════════════════════════════════════

class IdentidadNegocio {
  final String urlLogo;
  final String? logoPublicId;
  final String urlFachada;
  final String? fachadaPublicId;

  const IdentidadNegocio({
    this.urlLogo = '',
    this.logoPublicId,
    this.urlFachada = '',
    this.fachadaPublicId,
  });

  IdentidadNegocio copyWith({
    String? urlLogo,
    String? logoPublicId,
    String? urlFachada,
    String? fachadaPublicId,
  }) {
    return IdentidadNegocio(
      urlLogo: urlLogo ?? this.urlLogo,
      logoPublicId: logoPublicId ?? this.logoPublicId,
      urlFachada: urlFachada ?? this.urlFachada,
      fachadaPublicId: fachadaPublicId ?? this.fachadaPublicId,
    );
  }

  static IdentidadNegocio fromMap(Map<String, dynamic>? data) {
    if (data == null) return const IdentidadNegocio();
    return IdentidadNegocio(
      urlLogo: data['urlLogo'] as String? ?? '',
      logoPublicId: data['logoPublicId'] as String?,
      urlFachada: data['urlFachada'] as String? ?? '',
      fachadaPublicId: data['fachadaPublicId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'urlLogo': urlLogo,
      'logoPublicId': logoPublicId,
      'urlFachada': urlFachada,
      'fachadaPublicId': fachadaPublicId,
    };
  }
}