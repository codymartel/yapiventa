import 'package:mobile/features/productos/domain/models/cantidad_base.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

import 'unidad_registrada.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormateadorPresentacion
// ═════════════════════════════════════════════════════════════════════════
// Da una etiqueta legible a un FormatoPresentacion SIN usar double.
//
// Convierte la cantidad (siempre en unidad base) a la unidad visible usando
// aritmética de fracciones (n/d simplificada). Solo admite cuartos:
//   - 250 g  en kg  -> "1/4 kg"
//   - 500 g  en kg  -> "1/2 kg"
//   - 750 g  en kg  -> "3/4 kg"
//   - 1500 ml en L  -> "1 1/2 L"
//
// Si la conversión no es expresable en cuartos (ej. 3/5), la etiqueta cae a
// la unidad base: 600 ml en L -> "600 ml". NUNCA emite "0.25", "0.5",
// "0.75" ni "1.5".
// ═════════════════════════════════════════════════════════════════════════
class FormateadorPresentacion {
  FormateadorPresentacion._();

  /// Construye una CantidadBase reutilizando el dominio de productos.
  static CantidadBase cantidadEnFamilia(FamiliaUnidad familia, int valor) {
    switch (familia) {
      case FamiliaUnidad.conteo:
        return CantidadBase.unidades(valor);
      case FamiliaUnidad.peso:
        return CantidadBase.gramos(valor);
      case FamiliaUnidad.volumen:
        return CantidadBase.mililitros(valor);
      case FamiliaUnidad.longitud:
        return CantidadBase.milimetros(valor);
      case FamiliaUnidad.area:
        return CantidadBase.centimetrosCuadrados(valor);
    }
  }

  /// Etiqueta de [cantidad] (en unidad base) expresada en [unidad].
  static String formatear(CantidadBase cantidad, UnidadRegistrada unidad) {
    if (!RegistroUnidades.esDeFamilia(unidad, cantidad.familia)) {
      throw ArgumentError.value(
        unidad,
        'unidad',
        'La unidad no pertenece a la familia ${cantidad.familia}.',
      );
    }

    // Fracción simplificada valor / factorBase (nunca double).
    final mcd = _mcd(cantidad.valor, unidad.factorBase);
    final numerador = cantidad.valor ~/ mcd;
    final denominador = unidad.factorBase ~/ mcd;

    if (denominador == 1) return '$numerador ${unidad.nombre}';

    // Solo cuartos: 1/4, 1/2, 3/4 y mixtos como 1 1/2.
    if (denominador == 2 || denominador == 4) {
      if (numerador < denominador) {
        return '$numerador/$denominador ${unidad.nombre}';
      }
      final enteros = numerador ~/ denominador;
      final resto = numerador % denominador;
      return '$enteros $resto/$denominador ${unidad.nombre}';
    }

    // No expresable en cuartos -> cae a la unidad base (ej. 600 ml).
    final base = RegistroUnidades.baseDe(cantidad.familia);
    return '${cantidad.valor} ${base.nombre}';
  }

  static int _mcd(int a, int b) {
    var x = a;
    var y = b;
    while (y != 0) {
      final resto = x % y;
      x = y;
      y = resto;
    }
    return x;
  }
}
