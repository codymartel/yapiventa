// ═════════════════════════════════════════════════════════════════════════
// HorarioDia
// ═════════════════════════════════════════════════════════════════════════
// Migración directa de tu `data class HorarioDia` + la constante
// `DIAS_SEMANA` que estaba suelta en el archivo Kotlin.
// ═════════════════════════════════════════════════════════════════════════

class HorarioDia {
  final String dia;
  final String apertura;
  final String cierre;
  final bool activo;

  const HorarioDia({
    required this.dia,
    required this.apertura,
    required this.cierre,
    required this.activo,
  });

  HorarioDia copyWith({
    String? dia,
    String? apertura,
    String? cierre,
    bool? activo,
  }) {
    return HorarioDia(
      dia: dia ?? this.dia,
      apertura: apertura ?? this.apertura,
      cierre: cierre ?? this.cierre,
      activo: activo ?? this.activo,
    );
  }
}

/// Equivale a tu `val DIAS_SEMANA = listOf(...)`.
const List<String> diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];