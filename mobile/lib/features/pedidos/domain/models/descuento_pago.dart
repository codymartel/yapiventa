// ═════════════════════════════════════════════════════════════════════════
// DescuentoPago
// ═════════════════════════════════════════════════════════════════════════
// El descuento que el negocio configura para una forma de pago («5 % pagando
// con Yape desde S/ 20»). Todo en ENTEROS:
//
//   - porcentaje → [valor] en centésimas de punto: 5 % = 500, 7,5 % = 750.
//   - monto fijo → [valor] en céntimos: S/ 2,00 = 200.
//   - [minimoCentavos]: el subtotal desde el que se aplica.
//
// Quien lee la configuración del negocio (que guarda decimales) convierte una
// sola vez a estos enteros.
// ═════════════════════════════════════════════════════════════════════════
enum TipoDescuentoPago { ninguno, porcentaje, montoFijo }

class DescuentoPago {
  const DescuentoPago._(this.tipo, this.valor, this.minimoCentavos);

  /// Sin descuento.
  static const DescuentoPago ninguno = DescuentoPago._(
    TipoDescuentoPago.ninguno,
    0,
    0,
  );

  const DescuentoPago.porcentaje({
    required int centesimas,
    int minimoCentavos = 0,
  }) : this._(TipoDescuentoPago.porcentaje, centesimas, minimoCentavos);

  const DescuentoPago.montoFijo({required int centavos, int minimoCentavos = 0})
    : this._(TipoDescuentoPago.montoFijo, centavos, minimoCentavos);

  final TipoDescuentoPago tipo;
  final int valor;
  final int minimoCentavos;
}
