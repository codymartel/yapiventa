// ═════════════════════════════════════════════════════════════════════════
// Entradas numéricas del formulario de producto (PURAS, sin Flutter)
// ═════════════════════════════════════════════════════════════════════════
// Conversión entre lo que escribe la persona y los enteros del dominio.
// REGLA: nunca se usa double. La parte entera y la decimal se parsean como
// texto y se calculan con aritmética de enteros, así "4,35" kg con
// factorBase 1000 da exactamente 4350 g.
//
// El truncamiento es hacia abajo (la web nunca promete más de lo que hay),
// pero un valor MAYOR que cero que truncado da cero se RECHAZA con mensaje:
// "0,0004" kg son 0,4 g, y el dominio de medidas no guarda fracciones de
// gramo.
// ═════════════════════════════════════════════════════════════════════════

/// Resultado de convertir texto a cantidad entera en unidad base.
class ConversionCantidad {
  const ConversionCantidad._({this.base, this.error});

  const ConversionCantidad.valida(int base) : this._(base: base, error: null);

  const ConversionCantidad.invalida(String error)
    : this._(base: null, error: error);

  final int? base;
  final String? error;

  bool get esValida => error == null && base != null;
}

/// Cantidad de decimales que admite una unidad visual según su factor:
/// 1000 g en 1 kg → 3 decimales; 10 mm en 1 cm → 1; 10000 cm² en 1 m² → 4.
int decimalesDeFactor(int factorBase) {
  if (factorBase <= 0) return 0;
  return factorBase.toString().length - 1;
}

/// Convierte un texto en unidad visual a la unidad base (entero).
/// Acepta "4,35", "4.35", ".5" y "0,5". Rechaza negativos, letras y
/// valores que truncados darían 0.
ConversionCantidad textoAUnidadBase(
  String texto,
  int factorBase, {
  required String unidadBase,
}) {
  if (factorBase <= 0) {
    return const ConversionCantidad.invalida('Unidad inválida.');
  }
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) {
    return const ConversionCantidad.invalida('Escribe una cantidad.');
  }

  final match = RegExp(r'^(\d*)(?:\.(\d*))?$').firstMatch(limpio);
  if (match == null) {
    return const ConversionCantidad.invalida(
      'Usa solo números, con punto o coma para los decimales.',
    );
  }
  final enteros = match.group(1) ?? '';
  final decimales = match.group(2) ?? '';
  if (enteros.isEmpty && decimales.isEmpty) {
    return const ConversionCantidad.invalida('Escribe una cantidad.');
  }

  final parteEntera = enteros.isEmpty ? 0 : int.parse(enteros);
  final digitos = decimalesDeFactor(factorBase);
  final decimalNormalizado = decimales.isEmpty
      ? ''
      : (decimales.length <= digitos
            ? decimales.padRight(digitos, '0')
            : decimales.substring(0, digitos));
  final base =
      parteEntera * factorBase +
      (decimalNormalizado.isEmpty ? 0 : int.parse(decimalNormalizado));

  if (base <= 0) {
    return ConversionCantidad.invalida(
      'La cantidad es más pequeña que 1 $unidadBase.',
    );
  }
  return ConversionCantidad.valida(base);
}

/// Texto (con coma decimal) de una cantidad base en la unidad visual.
/// Se usa para precargar el formulario al editar: 1500 g → "1,5".
String baseATextoVisual(int base, int factorBase) {
  if (factorBase <= 0) return base.toString();
  final digitos = decimalesDeFactor(factorBase);
  final enteros = base ~/ factorBase;
  if (digitos == 0) return enteros.toString();
  final decimal = (base % factorBase).toString().padLeft(digitos, '0');
  final decimalLimpio = decimal.replaceFirst(RegExp(r'0+$'), '');
  if (decimalLimpio.isEmpty) return '$enteros';
  return '$enteros,$decimalLimpio';
}

/// Convierte soles escritos ("18,25") a céntimos enteros. null si está
/// vacío o no es un número válido de como máximo 2 decimales.
int? textoACentavos(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  final match = RegExp(r'^(\d*)(?:\.(\d{0,2}))?$').firstMatch(limpio);
  if (match == null) return null;
  final enteros = match.group(1) ?? '';
  final decimales = match.group(2) ?? '';
  if (enteros.isEmpty && decimales.isEmpty) return null;
  final parteEntera = enteros.isEmpty ? 0 : int.parse(enteros);
  final decimal = decimales.padRight(2, '0');
  return parteEntera * 100 + int.parse(decimal);
}

/// Texto con coma decimal a partir de céntimos: 1025 → "10,25".
String centavosATexto(int centavos) {
  final soles = centavos ~/ 100;
  final decimal = (centavos % 100).abs().toString().padLeft(2, '0');
  return '$soles,$decimal';
}
