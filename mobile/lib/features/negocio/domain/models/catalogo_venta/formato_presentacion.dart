import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

import 'formateador_presentacion.dart';
import 'unidad_registrada.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormatoPresentacion
// ═════════════════════════════════════════════════════════════════════════
// Un tamaño físico de una OpcionPresentacion (ej. "botella de 625 ml",
// "caja de 250 g"). Siempre trabaja en la UNIDAD BASE de la familia:
//   - peso     -> gramos
//   - volumen  -> mililitros
//   - longitud -> milímetros
//   - area     -> centímetros²
//   - conteo   -> unidades
//
// El valor jamás se guarda en la unidad visible: [unidadVisible] es solo la
// presentación y [etiqueta] se deriva con FormateadorPresentacion (sin
// double, sin duplicar el valor base). Un "1000 ml" y un "1 L" son EL MISMO
// formato normalizado (valorBase = 1000, familia volumen).
// ═════════════════════════════════════════════════════════════════════════
class FormatoPresentacion {
  final int valorBase;
  final FamiliaUnidad familia;
  final UnidadRegistrada unidadVisible;

  FormatoPresentacion._({
    required this.valorBase,
    required this.familia,
    required this.unidadVisible,
  });

  /// Valida y construye un formato. Lanza [ArgumentError] si es inválido.
  factory FormatoPresentacion({
    required int valorBase,
    required FamiliaUnidad familia,
    required UnidadRegistrada unidadVisible,
  }) {
    final error = validar(
      valorBase: valorBase,
      familia: familia,
      unidadVisible: unidadVisible,
    );
    if (error != null) {
      throw ArgumentError.value(valorBase, 'valorBase', error);
    }
    return FormatoPresentacion._(
      valorBase: valorBase,
      familia: familia,
      unidadVisible: unidadVisible,
    );
  }

  /// null si es válido; mensaje de error en español en caso contrario.
  static String? validar({
    required int valorBase,
    required FamiliaUnidad familia,
    required UnidadRegistrada unidadVisible,
  }) {
    if (valorBase <= 0) {
      return 'El valor base debe ser un entero positivo.';
    }
    if (!RegistroUnidades.esDeFamilia(unidadVisible, familia)) {
      return 'La unidad visible no pertenece a la familia $familia.';
    }
    return null;
  }

  /// Etiqueta derivada, ej. "625 ml", "1/4 kg", "1 1/2 L".
  String get etiqueta => FormateadorPresentacion.formatear(
    FormateadorPresentacion.cantidadEnFamilia(familia, valorBase),
    unidadVisible,
  );

  /// Igualdad por la cantidad normalizada (familia + valorBase en base).
  bool esMismoFormato(FormatoPresentacion otro) =>
      otro.familia == familia && otro.valorBase == valorBase;

  @override
  bool operator ==(Object other) {
    return other is FormatoPresentacion &&
        other.valorBase == valorBase &&
        other.familia == familia &&
        other.unidadVisible == unidadVisible;
  }

  @override
  int get hashCode => Object.hash(valorBase, familia, unidadVisible);

  @override
  String toString() => 'FormatoPresentacion($etiqueta)';
}
