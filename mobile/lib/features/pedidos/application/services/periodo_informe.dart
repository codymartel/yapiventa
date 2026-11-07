import 'resumen_dia_pedidos.dart';

// ═════════════════════════════════════════════════════════════════════════
// PeriodoInforme
// ═════════════════════════════════════════════════════════════════════════
// Los días que cubre un informe y los del periodo anterior con el que se
// compara. Funciones puras; los días son claves AAAA-MM-DD (hora de Lima).
//
//   hoy     → hoy                     vs ayer
//   semana  → los últimos 7 días      vs los 7 de antes
//   mes     → del 1 del mes hasta hoy vs el mismo tramo del mes anterior
//   dia     → un día elegido          vs el día anterior
//
// Cada periodo se lee con UNA consulta por rango (como máximo 31 documentos).
// ═════════════════════════════════════════════════════════════════════════
enum TipoPeriodo { hoy, semana, mes, dia }

class PeriodoInforme {
  const PeriodoInforme._({
    required this.tipo,
    required this.desde,
    required this.hasta,
    required this.anteriorDesde,
    required this.anteriorHasta,
  });

  /// [dia] solo se usa con [TipoPeriodo.dia]: debe ser AAAA-MM-DD y no puede
  /// ser posterior a hoy.
  factory PeriodoInforme.de(TipoPeriodo tipo, DateTime ahora, {String? dia}) {
    final hoy = _fecha(ResumenDiaPedidos.claveDia(ahora));
    switch (tipo) {
      case TipoPeriodo.hoy:
        return _armar(tipo, hoy, hoy, _sumar(hoy, -1), _sumar(hoy, -1));
      case TipoPeriodo.semana:
        final desde = _sumar(hoy, -6);
        return _armar(tipo, desde, hoy, _sumar(hoy, -13), _sumar(hoy, -7));
      case TipoPeriodo.mes:
        final desde = DateTime.utc(hoy.year, hoy.month, 1);
        final mesAnterior = DateTime.utc(hoy.year, hoy.month - 1, 1);
        final largoAnterior = DateTime.utc(hoy.year, hoy.month, 0).day;
        final tramo = hoy.day < largoAnterior ? hoy.day : largoAnterior;
        return _armar(
          tipo,
          desde,
          hoy,
          mesAnterior,
          DateTime.utc(mesAnterior.year, mesAnterior.month, tramo),
        );
      case TipoPeriodo.dia:
        final elegido = dia == null ? null : _intentarFecha(dia);
        if (elegido == null || elegido.isAfter(hoy)) {
          throw ArgumentError.value(dia, 'dia', 'Día inválido o futuro.');
        }
        return _armar(
          tipo,
          elegido,
          elegido,
          _sumar(elegido, -1),
          _sumar(elegido, -1),
        );
    }
  }

  final TipoPeriodo tipo;

  /// Primer y último día (incluidos).
  final String desde;
  final String hasta;
  final String anteriorDesde;
  final String anteriorHasta;

  static PeriodoInforme _armar(
    TipoPeriodo tipo,
    DateTime desde,
    DateTime hasta,
    DateTime anteriorDesde,
    DateTime anteriorHasta,
  ) {
    return PeriodoInforme._(
      tipo: tipo,
      desde: _clave(desde),
      hasta: _clave(hasta),
      anteriorDesde: _clave(anteriorDesde),
      anteriorHasta: _clave(anteriorHasta),
    );
  }

  static final RegExp _formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static DateTime _fecha(String clave) => _intentarFecha(clave)!;

  /// null si no tiene la forma AAAA-MM-DD o el día no existe (2026-02-30).
  static DateTime? _intentarFecha(String clave) {
    if (!_formato.hasMatch(clave)) return null;
    final y = int.parse(clave.substring(0, 4));
    final m = int.parse(clave.substring(5, 7));
    final d = int.parse(clave.substring(8, 10));
    final fecha = DateTime.utc(y, m, d);
    // Un día que no existe se corre al mes siguiente: no coincide.
    return fecha.year == y && fecha.month == m && fecha.day == d ? fecha : null;
  }

  static DateTime _sumar(DateTime fecha, int dias) =>
      DateTime.utc(fecha.year, fecha.month, fecha.day + dias);

  static String _clave(DateTime f) {
    final m = f.month.toString().padLeft(2, '0');
    final d = f.day.toString().padLeft(2, '0');
    return '${f.year.toString().padLeft(4, '0')}-$m-$d';
  }
}
