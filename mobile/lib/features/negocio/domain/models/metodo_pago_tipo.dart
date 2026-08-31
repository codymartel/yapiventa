// ═════════════════════════════════════════════════════════════════════════
// MetodoPagoTipo + TipoDescuento
// ═════════════════════════════════════════════════════════════════════════
// Migración de tu `sealed class MetodoPagoTipo` (Yape, Plin, Efectivo,
// Transferencia) + `enum class TipoDescuento`.
//
// En Kotlin, sealed class con objects fijos (Yape, Plin, etc.) es lo más
// parecido a un enum "enriquecido" (con más de un dato por valor). En
// Dart, la forma más directa de migrar esto sin sobre-complicar es una
// clase normal con instancias `static const`, que es exactamente lo que
// hacemos aquí — mismo comportamiento, sin necesitar sellar la clase (en
// Dart eso requeriría el modificador `sealed` de Dart 3, pero como no
// necesitamos herencia externa aquí, una clase simple con instancias
// fijas ya cumple lo mismo).
// ═════════════════════════════════════════════════════════════════════════

enum TipoDescuento { porcentaje, montoFijo }

class MetodoPagoTipo {
  final String id;
  final String nombre;
  final String icono;
  final bool permiteNumeroPersonalizado;
  final bool permiteDescuento;

  const MetodoPagoTipo._({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.permiteNumeroPersonalizado,
    required this.permiteDescuento,
  });

  static const yape = MetodoPagoTipo._(
    id: 'yape',
    nombre: 'Yape',
    icono: '📱',
    permiteNumeroPersonalizado: true,
    permiteDescuento: true,
  );

  static const plin = MetodoPagoTipo._(
    id: 'plin',
    nombre: 'Plin',
    icono: '💳',
    permiteNumeroPersonalizado: true,
    permiteDescuento: true,
  );

  static const efectivo = MetodoPagoTipo._(
    id: 'efectivo',
    nombre: 'Efectivo',
    icono: '💵',
    permiteNumeroPersonalizado: false,
    permiteDescuento: false,
  );

  static const transferencia = MetodoPagoTipo._(
    id: 'transferencia',
    nombre: 'Transferencia',
    icono: '🏦',
    permiteNumeroPersonalizado: false,
    permiteDescuento: false,
  );

  /// Equivale a `MetodoPagoTipo.todos` en Kotlin.
  static const List<MetodoPagoTipo> todos = [yape, plin, efectivo, transferencia];

  /// Equivale a `MetodoPagoTipo.porId(id)` en Kotlin.
  static MetodoPagoTipo? porId(String id) {
    for (final tipo in todos) {
      if (tipo.id == id) return tipo;
    }
    return null;
  }
}