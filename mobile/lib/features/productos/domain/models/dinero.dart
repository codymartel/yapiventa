// ═════════════════════════════════════════════════════════════════════════
// Dinero
// ═════════════════════════════════════════════════════════════════════════
// Valor monetario sin decimales de punto flotante: se guarda en CÉNTIMOS
// como entero. Toda la aritmética de precios usa solo int.
//
// La conversión de soles ("10.50") a céntimos (1050) es responsabilidad
// futura de la UI, nunca de este modelo.
// ═════════════════════════════════════════════════════════════════════════
class Dinero {
  final int centimos;

  const Dinero(this.centimos) : assert(centimos >= 0);

  factory Dinero.desdeSoles(int soles) {
    if (soles < 0) {
      throw ArgumentError.value(
        soles,
        'soles',
        'El monto no puede ser negativo.',
      );
    }
    return Dinero(soles * 100);
  }

  /// Precio redondeado hacia abajo (never sobrepasa) al operar con enteros.
  Dinero operator +(Dinero other) => Dinero(centimos + other.centimos);

  Dinero operator -(Dinero other) {
    final resultado = centimos - other.centimos;
    if (resultado < 0) {
      throw ArgumentError('El resultado no puede ser negativo.');
    }
    return Dinero(resultado);
  }

  bool operator <=(Dinero other) => centimos <= other.centimos;
  bool operator <(Dinero other) => centimos < other.centimos;
  bool operator >=(Dinero other) => centimos >= other.centimos;
  bool operator >(Dinero other) => centimos > other.centimos;

  @override
  bool operator ==(Object other) =>
      other is Dinero && other.centimos == centimos;
  @override
  int get hashCode => centimos.hashCode;

  @override
  String toString() => 'Dinero($centimos céntimos)';
}
