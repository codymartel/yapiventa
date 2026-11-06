import 'contadores_dia.dart';

// ═════════════════════════════════════════════════════════════════════════
// ResumenVentasDia · EntregadoReciente
// ═════════════════════════════════════════════════════════════════════════
// El resumen de un día de ventas: UN documento por día (negocios/{id}/
// resumenes/AAAA-MM-DD). Se actualiza dentro de las transacciones de confirmar
// y entregar, así el panel muestra «Ventas de hoy», el ticket y los últimos
// entregados leyendo UN solo documento, sin leer cada pedido cerrado.
//
// Todo en enteros (céntimos y minutos). El ticket y el promedio se CALCULAN al
// mostrarlos: no se guardan (los totales se calculan, no se escriben).
// ═════════════════════════════════════════════════════════════════════════
class EntregadoReciente {
  const EntregadoReciente({
    required this.pedidoId,
    this.clave = '',
    this.cliente = '',
    this.productos = '',
    this.totalCentavos = 0,
    this.metodoPago = '',
    this.cobrado = false,
    this.hora,
  });

  final String pedidoId;
  final String clave;
  final String cliente;

  /// Resumen de lo pedido («350 Queso andino, 2× Inca»), ya armado.
  final String productos;
  final int totalCentavos;
  final String metodoPago;
  final bool cobrado;

  /// Momento en que se entregó.
  final DateTime? hora;
}

class ResumenVentasDia {
  const ResumenVentasDia({
    required this.dia,
    this.ventasCentavos = 0,
    this.entregados = 0,
    this.confirmados = 0,
    this.sumaMinutosConfirmar = 0,
    this.ultimosEntregados = const [],
    this.contadores = ContadoresDia.vacio,
  });

  /// Un día sin movimientos (el documento todavía no existe).
  const ResumenVentasDia.vacio(String dia) : this(dia: dia);

  /// AAAA-MM-DD, hora de Lima.
  final String dia;

  /// Suma del total de los pedidos entregados ese día.
  final int ventasCentavos;
  final int entregados;

  /// Pedidos confirmados ese día y la suma de minutos que tardaron en
  /// confirmarse (desde que llegaron).
  final int confirmados;
  final int sumaMinutosConfirmar;

  /// Los últimos entregados, del más nuevo al más viejo (máximo 5).
  final List<EntregadoReciente> ultimosEntregados;

  /// Lo vendido por forma de pago, entrega, hora, producto, variable y combo,
  /// lo de mostrador y lo anulado. Un resumen viejo no los trae: vienen vacíos.
  final ContadoresDia contadores;

  /// Venta promedio por pedido entregado, en céntimos, redondeada hacia abajo
  /// una sola vez. null si todavía no se entregó nada (no se divide entre 0).
  int? get ticketCentavos {
    if (entregados <= 0) return null;
    return ventasCentavos ~/ entregados;
  }

  /// Minutos promedio para confirmar un pedido. null si no se confirmó ninguno.
  int? get minutosPromedioConfirmar {
    if (confirmados <= 0) return null;
    return sumaMinutosConfirmar ~/ confirmados;
  }
}
