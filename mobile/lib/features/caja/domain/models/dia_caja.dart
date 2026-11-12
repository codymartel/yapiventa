import '../../../pedidos/domain/models/resumen_ventas_dia.dart';

// ═════════════════════════════════════════════════════════════════════════
// GastosDia · DiaCaja
// ═════════════════════════════════════════════════════════════════════════
// El día de Caja, leído de UN solo documento (el resumen del día): lo vendido
// (lo escribe Pedidos al cobrar y entregar) y lo gastado (lo escribe Caja).
// Todo en céntimos enteros; los totales que se muestran se CALCULAN aquí, no
// se guardan.
// ═════════════════════════════════════════════════════════════════════════
class GastosDia {
  const GastosDia({
    this.totalCentavos = 0,
    this.cantidad = 0,
    this.porPago = const {},
    this.porMotivo = const {},
  });

  static const GastosDia vacio = GastosDia();

  final int totalCentavos;
  final int cantidad;

  /// Céntimos gastados por forma de pago («efectivo», «yape»…).
  final Map<String, int> porPago;

  /// Céntimos gastados por motivo («comida», «pasaje»…).
  final Map<String, int> porMotivo;

  /// El día con un gasto más.
  GastosDia mas({
    required int centavos,
    required String pago,
    required String motivo,
  }) {
    return GastosDia(
      totalCentavos: totalCentavos + centavos,
      cantidad: cantidad + 1,
      porPago: _sumar(porPago, pago, centavos),
      porMotivo: _sumar(porMotivo, motivo, centavos),
    );
  }

  /// El día sin un gasto (anulado). Nada baja de cero y lo que llega a cero
  /// se quita de la lista.
  GastosDia menos({
    required int centavos,
    required String pago,
    required String motivo,
  }) {
    return GastosDia(
      totalCentavos: _piso(totalCentavos - centavos),
      cantidad: _piso(cantidad - 1),
      porPago: _sumar(porPago, pago, -centavos),
      porMotivo: _sumar(porMotivo, motivo, -centavos),
    );
  }

  static Map<String, int> _sumar(Map<String, int> mapa, String clave, int v) {
    final copia = Map<String, int>.of(mapa);
    final nuevo = (copia[clave] ?? 0) + v;
    if (nuevo <= 0) {
      copia.remove(clave);
    } else {
      copia[clave] = nuevo;
    }
    return copia;
  }

  static int _piso(int valor) => valor < 0 ? 0 : valor;
}

class DiaCaja {
  const DiaCaja({required this.ventas, this.gastos = GastosDia.vacio});

  DiaCaja.vacio(String dia) : this(ventas: ResumenVentasDia.vacio(dia));

  /// La clave con la que ventas y gastos guardan el efectivo.
  static const String claveEfectivo = 'efectivo';

  final ResumenVentasDia ventas;
  final GastosDia gastos;

  String get dia => ventas.dia;

  int get ventasCentavos => ventas.ventasCentavos;
  int get gastosCentavos => gastos.totalCentavos;

  /// Lo que queda del día: ventas menos gastos. Puede ser negativo (se gastó
  /// más de lo que se vendió).
  int get quedaCentavos => ventasCentavos - gastosCentavos;

  /// Entregado hoy y todavía sin cobrar (no está en la caja).
  int get porCobrarCentavos => ventas.contadores.porCobrarCentavos;

  /// Efectivo que debe haber por lo de HOY: lo COBRADO hoy en efectivo menos
  /// lo gastado en efectivo (lo entregado sin cobrar no entra). Negativo si
  /// se sacó más de lo que entró hoy.
  int get efectivoCentavos =>
      (ventas.contadores.porPago[claveEfectivo] ?? 0) -
      (gastos.porPago[claveEfectivo] ?? 0);
}
