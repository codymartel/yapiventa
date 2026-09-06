// ═════════════════════════════════════════════════════════════════════════
// SubidorDeImagenes (interfaz)
// ═════════════════════════════════════════════════════════════════════════
// Molde genérico para subir imágenes, sin saber qué proveedor hay detrás.
// Hoy la implementación es CloudinaryService. El día que migres a
// Firebase Storage (u otro), solo creas una clase nueva que implemente
// esto — nada de productos_provider.dart ni de las pantallas cambia.
// ═════════════════════════════════════════════════════════════════════════

class ResultadoSubida {
  final String url;
  final String identificador; // public_id (Cloudinary) o path (Firebase Storage)

  const ResultadoSubida({required this.url, required this.identificador});
}

abstract class SubidorDeImagenes {
  /// Sube [bytes] (la imagen ya comprimida) dentro de [carpeta]
  /// (ej. "usuarios/{uid}/productos") y devuelve la URL pública +
  /// el identificador necesario para poder borrarla después.
  Future<ResultadoSubida> subir({
    required List<int> bytes,
    required String carpeta,
    required String nombreArchivo,
  });

  /// Borra una imagen usando su identificador (public_id o path).
  /// Puede no estar implementado aún (Cloudinary unsigned no permite
  /// borrar sin firma) — en ese caso, lanza UnimplementedError.
  Future<void> borrar(String identificador);
}