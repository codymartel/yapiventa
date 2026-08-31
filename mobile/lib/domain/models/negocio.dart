// ═════════════════════════════════════════════════════════════════════════
// Negocio
// ═════════════════════════════════════════════════════════════════════════
// Migración directa de tu `data class Negocio`. Sin cambios de lógica.
// ═════════════════════════════════════════════════════════════════════════

class Negocio {
  final String idUsuario; // UID de Firebase Auth
  final String nombreNegocio; // Ej: "Abarrotes Don Pepe"
  final String tipoNegocio; // Ej: "Bodega"
  final String direccion;
  final String telefono;

  const Negocio({
    this.idUsuario = '',
    this.nombreNegocio = '',
    this.tipoNegocio = '',
    this.direccion = '',
    this.telefono = '',
  });
}