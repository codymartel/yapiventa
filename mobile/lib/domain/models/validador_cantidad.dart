// ═════════════════════════════════════════════════════════════════════════
// ValidadorCantidad
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Valida y convierte cantidades que el usuario puede escribir en DOS
// formatos distintos:
//   - Decimal:  "0.5", "1.5", "1000"
//   - Fracción: "1/2", "3/4", "1 1/2" (entero + fracción con un espacio)
//
// Internamente TODO se convierte y se guarda como decimal (double) —
// eso es lo único matemáticamente seguro para sumar/restar stock. La
// fracción es solo una forma de ENTRADA más natural para el usuario
// ("medio kilo" en vez de "0.5 kg"), nunca el dato que se guarda.
//
// REGLAS (solo formato, sin límites de negocio inventados — una
// ferretería puede vender 5000 kg de cemento, eso es válido):
//   - Decimal: separador punto, máximo 2 decimales, mayor que 0
//   - Fracción: numerador/denominador o entero + fracción con un
//     espacio; denominador nunca 0; numerador de la parte fraccionaria
//     siempre menor que el denominador (2 1/2, no 1 5/2)
//
// CON QUÉ SE CONECTA:
// - Lo usa cualquier pantalla donde el usuario escriba una cantidad
//   fraccionable (ej. "agregar producto", configuración de unidades).
// - Se apoya en UnidadesMedida.fraccionADecimal para las fracciones
//   comunes (1/8, 1/4, 1/2, 3/4), pero también soporta cualquier
//   fracción escrita a mano por el usuario, no solo esas 4.
// ═════════════════════════════════════════════════════════════════════════

/// Resultado de validar una cantidad: si es válida, trae el valor
/// decimal ya calculado; si no, trae el mensaje de error para mostrar.
class ResultadoValidacion {
  final bool esValido;
  final double? valorDecimal;
  final String? mensajeError;

  const ResultadoValidacion._({
    required this.esValido,
    this.valorDecimal,
    this.mensajeError,
  });

  factory ResultadoValidacion.valido(double valor) =>
      ResultadoValidacion._(esValido: true, valorDecimal: valor);

  factory ResultadoValidacion.invalido(String mensaje) =>
      ResultadoValidacion._(esValido: false, mensajeError: mensaje);
}

class ValidadorCantidad {
  ValidadorCantidad._();

  // Acepta "0.5", "1.5", "1000", "1000.25" — punto como separador,
  // máximo 2 decimales.
  static final RegExp _patronDecimal = RegExp(r'^\d+(\.\d{1,2})?$');

  // Acepta "1/2", "3/4", "12/8" — solo numerador/denominador.
  static final RegExp _patronFraccionSimple = RegExp(r'^(\d+)/(\d+)$');

  // Acepta "1 1/2", "2 3/4" — un entero, un espacio, y una fracción.
  static final RegExp _patronFraccionMixta = RegExp(r'^(\d+)\s(\d+)/(\d+)$');

  /// Punto de entrada principal: recibe lo que sea que el usuario haya
  /// escrito (decimal o fracción) y devuelve el resultado validado con
  /// su valor decimal ya calculado, listo para guardar/sumar.
  static ResultadoValidacion validar(String entrada) {
    final texto = entrada.trim();

    if (texto.isEmpty) {
      return ResultadoValidacion.invalido('Ingresa una cantidad.');
    }

    // Si tiene un "/", es fracción (simple o mixta). Si no, es decimal.
    if (texto.contains('/')) {
      return _validarFraccion(texto);
    } else {
      return _validarDecimal(texto);
    }
  }

  static ResultadoValidacion _validarDecimal(String texto) {
    if (!_patronDecimal.hasMatch(texto)) {
      return ResultadoValidacion.invalido(
        'Formato inválido. Usa punto para decimales, ej: 0.5 o 1.5',
      );
    }
    final valor = double.parse(texto);
    if (valor <= 0) {
      return ResultadoValidacion.invalido('La cantidad debe ser mayor que 0.');
    }
    return ResultadoValidacion.valido(valor);
  }

  static ResultadoValidacion _validarFraccion(String texto) {
    // Caso "entero numerador/denominador" (ej. "1 1/2")
    final matchMixta = _patronFraccionMixta.firstMatch(texto);
    if (matchMixta != null) {
      final entero = int.parse(matchMixta.group(1)!);
      final numerador = int.parse(matchMixta.group(2)!);
      final denominador = int.parse(matchMixta.group(3)!);

      final errorFraccion = _validarNumeradorDenominador(numerador, denominador);
      if (errorFraccion != null) return ResultadoValidacion.invalido(errorFraccion);

      final valor = entero + (numerador / denominador);
      return ResultadoValidacion.valido(valor);
    }

    // Caso "numerador/denominador" simple (ej. "1/2")
    final matchSimple = _patronFraccionSimple.firstMatch(texto);
    if (matchSimple != null) {
      final numerador = int.parse(matchSimple.group(1)!);
      final denominador = int.parse(matchSimple.group(2)!);

      final errorFraccion = _validarNumeradorDenominador(numerador, denominador);
      if (errorFraccion != null) return ResultadoValidacion.invalido(errorFraccion);

      final valor = numerador / denominador;
      return ResultadoValidacion.valido(valor);
    }

    return ResultadoValidacion.invalido(
      'Formato de fracción inválido. Usa algo como 1/2 o 1 1/2.',
    );
  }

  /// Reglas compartidas entre fracción simple y mixta: denominador
  /// nunca 0, y en la parte fraccionaria el numerador debe ser menor
  /// que el denominador (2 1/2 es válido, 1 5/2 no lo es — eso se
  /// escribe como 2 1/2).
  static String? _validarNumeradorDenominador(int numerador, int denominador) {
    if (denominador == 0) {
      return 'El denominador no puede ser 0.';
    }
    if (numerador >= denominador) {
      return 'La fracción no es válida. Por ejemplo, usa "2 1/2" en vez de "1 5/2".';
    }
    return null;
  }

  /// Utilidad inversa: convierte un decimal a su forma coloquial en
  /// fracción, SOLO para mostrar en pantalla (ej. reportes, panel).
  /// El dato guardado sigue siendo el decimal — esto no lo reemplaza,
  /// solo lo formatea para lectura humana cuando así se prefiera.
  ///
  /// Soporta las fracciones comunes (1/8, 1/4, 1/2, 3/4). Si el decimal
  /// no coincide con ninguna fracción común, se devuelve el mismo
  /// decimal como texto (ej. 0.3 se queda como "0.3", no se fuerza a
  /// una fracción rara).
  static String formatearComoFraccion(double valor) {
    final parteEntera = valor.truncate();
    final parteDecimal = valor - parteEntera;

    final  fraccionesConocidas = {
      0.125: '1/8',
      0.25: '1/4',
      0.5: '1/2',
      0.75: '3/4',
    };

    // Redondeamos a 3 decimales para evitar errores de precisión de
    // punto flotante al comparar (ej. 0.1 + 0.2 != 0.3 en binario).
    final decimalRedondeado =
        double.parse(parteDecimal.toStringAsFixed(3));

    final fraccionTexto = fraccionesConocidas[decimalRedondeado];

    if (fraccionTexto == null) {
      // No es una fracción común conocida — se muestra tal cual en
      // decimal, sin forzar una fracción que no es exacta.
      return valor.toString();
    }

    if (parteEntera == 0) {
      return fraccionTexto;
    }
    return '$parteEntera $fraccionTexto';
  }
}