import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

import 'unidad_registrada.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfiguracionMedida
// ═════════════════════════════════════════════════════════════════════════
// Regla de venta por MEDIDA de una familia de unidades (peso, volumen,
// longitud, área). Es la contraparte de FormatoPresentacion para
// ModoVenta.medida.
//
// REGLAS:
//   - [unidadBase] está PROTEGIDA: siempre es la unidad base de la familia
//     (g, ml, mm, cm²). El negocio nunca la elige.
//   - [unidadVisual] es la unidad que ve el cliente (kg, L, cm...).
//   - Los números se guardan SIEMPRE en la unidad base y SIN double.
//   - El mínimo y el incremento son positivos y en unidad base.
//   - Las cantidades rápidas respetan mínimo e incremento:
//       cantidad >= minimo && (cantidad - minimo) % incremento == 0
//   - Se permite vender por cantidad y/o por monto (al menos uno).
//   - El monto puede estar activo (venta por monto encendida), opcional
//     (disponible en el rubro pero apagada por defecto) o inactivo.
// ═════════════════════════════════════════════════════════════════════════
enum EstadoMonto { inactivo, opcional, activo }

class ConfiguracionMedida {
  final FamiliaUnidad familia;
  final UnidadRegistrada unidadBase;
  final UnidadRegistrada unidadVisual;
  final int minimoBase;
  final int incrementoBase;
  final List<int> cantidadesRapidasBase;
  final bool permiteCantidad;
  final EstadoMonto monto;
  final bool activa;

  ConfiguracionMedida._({
    required this.familia,
    required this.unidadBase,
    required this.unidadVisual,
    required this.minimoBase,
    required this.incrementoBase,
    required List<int> cantidadesRapidasBase,
    required this.permiteCantidad,
    required this.monto,
    required this.activa,
  }) : cantidadesRapidasBase = List.unmodifiable(cantidadesRapidasBase);

  /// El negocio puede vender por monto (activo u opcional).
  bool get permiteMonto => monto != EstadoMonto.inactivo;

  /// La venta por monto está encendida por defecto en este rubro.
  bool get montoActivo => monto == EstadoMonto.activo;

  /// Valida y construye la configuración. Lanza [ArgumentError] si es inválida.
  factory ConfiguracionMedida({
    required FamiliaUnidad familia,
    required UnidadRegistrada unidadVisual,
    required int minimoBase,
    required int incrementoBase,
    List<int> cantidadesRapidasBase = const [],
    bool permiteCantidad = true,
    EstadoMonto monto = EstadoMonto.activo,
    bool activa = true,
  }) {
    final error = validar(
      familia: familia,
      unidadVisual: unidadVisual,
      minimoBase: minimoBase,
      incrementoBase: incrementoBase,
      cantidadesRapidasBase: cantidadesRapidasBase,
      permiteCantidad: permiteCantidad,
      monto: monto,
    );
    if (error != null) {
      throw ArgumentError.value(familia, 'familia', error);
    }
    return ConfiguracionMedida._(
      familia: familia,
      unidadBase: RegistroUnidades.baseDe(familia),
      unidadVisual: unidadVisual,
      minimoBase: minimoBase,
      incrementoBase: incrementoBase,
      cantidadesRapidasBase: cantidadesRapidasBase,
      permiteCantidad: permiteCantidad,
      monto: monto,
      activa: activa,
    );
  }

  /// null si es válida; mensaje de error en español en caso contrario.
  static String? validar({
    required FamiliaUnidad familia,
    required UnidadRegistrada unidadVisual,
    required int minimoBase,
    required int incrementoBase,
    required List<int> cantidadesRapidasBase,
    required bool permiteCantidad,
    required EstadoMonto monto,
  }) {
    if (familia == FamiliaUnidad.conteo) {
      return 'La venta por medida no aplica a la familia de conteo.';
    }
    if (!RegistroUnidades.esDeFamilia(unidadVisual, familia)) {
      return 'La unidad visual no pertenece a la familia $familia.';
    }
    if (minimoBase <= 0) {
      return 'El mínimo debe ser un entero positivo.';
    }
    if (incrementoBase <= 0) {
      return 'El incremento debe ser un entero positivo.';
    }
    if (!permiteCantidad && monto == EstadoMonto.inactivo) {
      return 'Debe permitir venta por cantidad o por monto (o ambas).';
    }

    final normalizadas = <int>{};
    for (final cantidad in cantidadesRapidasBase) {
      if (cantidad < minimoBase) {
        return 'La cantidad rápida $cantidad es menor al mínimo $minimoBase.';
      }
      if ((cantidad - minimoBase) % incrementoBase != 0) {
        return 'La cantidad rápida $cantidad no respeta el incremento '
            '$incrementoBase a partir del mínimo.';
      }
      if (!normalizadas.add(cantidad)) {
        return 'La cantidad rápida $cantidad está duplicada.';
      }
    }
    return null;
  }
}
