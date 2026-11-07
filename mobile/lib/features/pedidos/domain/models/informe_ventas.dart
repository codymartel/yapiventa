// ═════════════════════════════════════════════════════════════════════════
// InformeVentas · InformeComparado · Variacion
// ═════════════════════════════════════════════════════════════════════════
// El informe de ventas de un periodo (hoy, semana, mes o un día), armado SOLO
// con los resúmenes diarios ya guardados: no se lee ningún pedido. Todo en
// enteros (céntimos y cantidades). El ticket y los porcentajes se calculan al
// mostrarlos, no se guardan.
// ═════════════════════════════════════════════════════════════════════════

/// Un día con sus ventas (para el mejor y el más flojo).
class DiaDeVentas {
  const DiaDeVentas({
    required this.dia,
    required this.ventasCentavos,
    required this.entregados,
  });

  /// AAAA-MM-DD, hora de Lima.
  final String dia;
  final int ventasCentavos;
  final int entregados;
}

/// Un puesto de un ranking (producto, variable o combo).
class PuestoRanking {
  const PuestoRanking({
    required this.clave,
    required this.nombre,
    required this.cantidad,
    required this.centavos,
  });

  final String clave;
  final String nombre;

  /// Unidades vendidas (en unidad base si se vende por medida).
  final int cantidad;
  final int centavos;
}

class InformeVentas {
  const InformeVentas({
    required this.desde,
    required this.hasta,
    this.ventasCentavos = 0,
    this.entregados = 0,
    this.diasConVentas = 0,
    this.mejorDia,
    this.diaMasFlojo,
    this.mostradorCentavos = 0,
    this.mostrador = 0,
    this.anuladas = 0,
    this.anuladasCentavos = 0,
    this.porPago = const {},
    this.porEntrega = const {},
    this.porHora = const {},
    this.productos = const [],
    this.variantes = const [],
    this.combos = const [],
  });

  /// Un periodo sin movimientos.
  const InformeVentas.vacio(String desde, String hasta)
    : this(desde: desde, hasta: hasta);

  /// Primer y último día del periodo (AAAA-MM-DD, ambos incluidos).
  final String desde;
  final String hasta;

  final int ventasCentavos;
  final int entregados;

  /// Días del periodo en que se entregó algo.
  final int diasConVentas;

  /// El día que más vendió y el que menos (entre los días con ventas). El más
  /// flojo es null si hubo un solo día con ventas o todos vendieron igual.
  final DiaDeVentas? mejorDia;
  final DiaDeVentas? diaMasFlojo;

  /// Lo vendido en mostrador (Caja) y lo anulado.
  final int mostradorCentavos;
  final int mostrador;
  final int anuladas;
  final int anuladasCentavos;

  /// Céntimos por forma de pago, por entrega (local, recojo, delivery) y por
  /// hora de Lima («09», «14»).
  final Map<String, int> porPago;
  final Map<String, int> porEntrega;
  final Map<String, int> porHora;

  /// Del que más vendió al que menos (los primeros del ranking).
  final List<PuestoRanking> productos;
  final List<PuestoRanking> variantes;
  final List<PuestoRanking> combos;

  /// Lo que no vino de Caja (la tienda). Solo es exacto para los días que ya
  /// guardan contadores.
  int get tiendaCentavos {
    final resto = ventasCentavos - mostradorCentavos;
    return resto < 0 ? 0 : resto;
  }

  /// Venta promedio por pedido entregado, redondeada hacia abajo una sola
  /// vez. null si no se entregó nada (no se divide entre 0).
  int? get ticketCentavos {
    if (entregados <= 0) return null;
    return ventasCentavos ~/ entregados;
  }

  bool get sinMovimientos => entregados == 0 && anuladas == 0;
}

/// Cuánto cambió un número contra el periodo anterior.
class Variacion {
  const Variacion({required this.diferencia, this.porcentaje});

  /// actual − anterior (puede ser negativa).
  final int diferencia;

  /// Cambio en porcentaje entero (hacia cero). null si el anterior era 0: no
  /// se puede dividir entre 0 y «+∞ %» no dice nada.
  final int? porcentaje;

  static Variacion entre(int actual, int anterior) {
    final diferencia = actual - anterior;
    return Variacion(
      diferencia: diferencia,
      porcentaje: anterior > 0 ? (diferencia * 100) ~/ anterior : null,
    );
  }
}

/// El informe del periodo junto con el anterior (si se pidió comparar).
class InformeComparado {
  const InformeComparado({required this.actual, this.anterior});

  final InformeVentas actual;
  final InformeVentas? anterior;

  Variacion? get ventas => anterior == null
      ? null
      : Variacion.entre(actual.ventasCentavos, anterior!.ventasCentavos);

  Variacion? get entregados => anterior == null
      ? null
      : Variacion.entre(actual.entregados, anterior!.entregados);

  /// null si alguno de los dos periodos no tiene ticket (sin entregas).
  Variacion? get ticket {
    final a = actual.ticketCentavos;
    final b = anterior?.ticketCentavos;
    if (a == null || b == null) return null;
    return Variacion.entre(a, b);
  }
}
