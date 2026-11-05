// ═════════════════════════════════════════════════════════════════════════
// TiempoTranscurrido
// ═════════════════════════════════════════════════════════════════════════
// «hace 4 min», «hace 2 h 40 min», «hace 3 d». Función pura: recibe la hora
// actual, no la lee, para poder probarla. Una fecha en el futuro (reloj del
// teléfono atrasado) o sin escribir todavía se muestra como «ahora».
// ═════════════════════════════════════════════════════════════════════════
abstract final class TiempoTranscurrido {
  static String hace(DateTime? fecha, DateTime ahora) {
    if (fecha == null) return 'ahora';
    final minutos = ahora.difference(fecha).inMinutes;
    if (minutos < 1) return 'ahora';
    if (minutos < 60) return 'hace $minutos min';
    final horas = minutos ~/ 60;
    if (horas < 24) {
      final resto = minutos % 60;
      return resto == 0 ? 'hace $horas h' : 'hace $horas h $resto min';
    }
    return 'hace ${horas ~/ 24} d';
  }
}
