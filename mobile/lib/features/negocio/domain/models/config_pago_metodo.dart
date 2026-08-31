import 'metodo_pago_tipo.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfigPagoMetodo
// ═════════════════════════════════════════════════════════════════════════
// Migración directa de tu `data class ConfigPagoMetodo`, más las funciones
// de validación de pago que estaban sueltas en el archivo Kotlin
// (valorDescuentoValido, montoMinimoValido) — las agrupamos aquí porque
// operan directamente sobre los datos de esta clase.
// ═════════════════════════════════════════════════════════════════════════

class ConfigPagoMetodo {
  final String metodoId;
  final bool activo;
  final String numeroPago;
  final bool descuentoActivo;
  final TipoDescuento tipoDescuento;
  final String valorDescuento;
  final String montoMinimo;

  const ConfigPagoMetodo({
    required this.metodoId,
    this.activo = false,
    this.numeroPago = '',
    this.descuentoActivo = false,
    this.tipoDescuento = TipoDescuento.porcentaje,
    this.valorDescuento = '',
    this.montoMinimo = '',
  });

  ConfigPagoMetodo copyWith({
    bool? activo,
    String? numeroPago,
    bool? descuentoActivo,
    TipoDescuento? tipoDescuento,
    String? valorDescuento,
    String? montoMinimo,
  }) {
    return ConfigPagoMetodo(
      metodoId: metodoId,
      activo: activo ?? this.activo,
      numeroPago: numeroPago ?? this.numeroPago,
      descuentoActivo: descuentoActivo ?? this.descuentoActivo,
      tipoDescuento: tipoDescuento ?? this.tipoDescuento,
      valorDescuento: valorDescuento ?? this.valorDescuento,
      montoMinimo: montoMinimo ?? this.montoMinimo,
    );
  }
}

/// Equivale a tu `fun valorDescuentoValido(valor, tipo)`.
bool valorDescuentoValido(String valor, TipoDescuento tipo) {
  if (valor.isEmpty) return true;
  final num_ = double.tryParse(valor);
  if (num_ == null) return false;
  switch (tipo) {
    case TipoDescuento.porcentaje:
      return num_ >= 0.0 && num_ <= 100.0;
    case TipoDescuento.montoFijo:
      return num_ >= 0.0;
  }
}

/// Equivale a tu `fun montoMinimoValido(m)`.
bool montoMinimoValido(String monto) {
  if (monto.isEmpty) return true;
  final num_ = double.tryParse(monto);
  return num_ != null && num_ >= 0;
}