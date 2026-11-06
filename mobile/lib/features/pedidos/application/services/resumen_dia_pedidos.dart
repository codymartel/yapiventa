import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// ResumenDiaPedidos
// ═════════════════════════════════════════════════════════════════════════
// Agrupa el historial por día (hora de Lima) para la vista «Historial».
// Suma solo lo entregado. Función pura, sin Flutter ni Firestore.
//
// Lima no tiene horario de verano: es UTC−5 todo el año. (Cuando haya
// moneda y país configurables, la zona horaria saldrá del negocio.)
// ═════════════════════════════════════════════════════════════════════════
class ResumenDia {
  const ResumenDia({
    required this.dia,
    required this.pedidos,
    required this.entregadosCentavos,
    required this.nEntregados,
    required this.nCancelados,
  });

  /// Día en formato AAAA-MM-DD.
  final String dia;

  /// Del más nuevo al más viejo.
  final List<Pedido> pedidos;
  final int entregadosCentavos;
  final int nEntregados;
  final int nCancelados;
}

abstract final class ResumenDiaPedidos {
  static const Duration _utcLima = Duration(hours: -5);

  /// AAAA-MM-DD del día en Lima. Sirve de clave para agrupar.
  static String claveDia(DateTime fecha) {
    final lima = fecha.toUtc().add(_utcLima);
    final mes = lima.month.toString().padLeft(2, '0');
    final dia = lima.day.toString().padLeft(2, '0');
    return '${lima.year}-$mes-$dia';
  }

  static const List<String> _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// «16:12»: la hora de Lima de un momento. (Hasta que el país del negocio
  /// fije la zona horaria.)
  static String horaLima(DateTime momento) {
    final lima = momento.toUtc().add(_utcLima);
    final h = lima.hour.toString().padLeft(2, '0');
    final m = lima.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// «2026-11-05» → «5 nov 2026». Si la clave no tiene esa forma, se devuelve
  /// tal cual.
  static String etiquetaDia(String clave) {
    final partes = clave.split('-');
    if (partes.length != 3) return clave;
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);
    if (mes == null || dia == null || mes < 1 || mes > 12) return clave;
    return '$dia ${_meses[mes - 1]} ${partes[0]}';
  }

  /// Días del más nuevo al más viejo. Los pedidos sin fecha se omiten.
  static List<ResumenDia> agrupar(List<Pedido> pedidos) {
    final porDia = <String, List<Pedido>>{};
    for (final pedido in pedidos) {
      final fecha = pedido.fecha;
      if (fecha == null) continue;
      porDia.putIfAbsent(claveDia(fecha), () => []).add(pedido);
    }

    final claves = porDia.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final clave in claves) _resumen(clave, porDia[clave]!)];
  }

  static ResumenDia _resumen(String dia, List<Pedido> delDia) {
    final ordenados = [...delDia]..sort((a, b) => b.fecha!.compareTo(a.fecha!));
    var entregadosCentavos = 0;
    var nEntregados = 0;
    var nCancelados = 0;
    for (final pedido in ordenados) {
      if (pedido.estado == EstadoPedido.entregado) {
        entregadosCentavos += pedido.totalCentavos;
        nEntregados++;
      } else if (pedido.estado == EstadoPedido.cancelado) {
        nCancelados++;
      }
    }
    return ResumenDia(
      dia: dia,
      pedidos: ordenados,
      entregadosCentavos: entregadosCentavos,
      nEntregados: nEntregados,
      nCancelados: nCancelados,
    );
  }
}
