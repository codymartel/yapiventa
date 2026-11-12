/// Tamaño de letra que elige la persona en Configuración. Se guarda en el
/// equipo (no en la cuenta) y se aplica a toda la app.
///
/// El porcentaje es entero para que guardar y comparar no dependa de
/// decimales; la escala final sí es `double` porque así la pide Flutter (no
/// es dinero ni stock).
enum TamanoLetra {
  normal('normal', 'Normal', 100),
  grande('grande', 'Grande', 115),
  muyGrande('muy_grande', 'Muy grande', 130);

  const TamanoLetra(this.clave, this.etiqueta, this.porcentaje);

  /// Lo que se guarda en el equipo. No cambiar: un valor guardado viejo
  /// dejaría de reconocerse y volvería a «Normal».
  final String clave;
  final String etiqueta;
  final int porcentaje;

  /// Tope de la escala final. El teléfono puede tener ya la letra grande:
  /// multiplicar sin tope dejaría pantallas imposibles de leer completas.
  static const escalaMaxima = 1.6;

  /// El tamaño guardado, o «Normal» si no hay nada o no se reconoce.
  static TamanoLetra desdeClave(String? clave) {
    for (final tamano in values) {
      if (tamano.clave == clave) return tamano;
    }
    return normal;
  }

  /// La escala que usa la app: la del teléfono por la elegida aquí, con tope.
  /// Nunca queda por debajo de la del teléfono (si ya pasaba el tope, se
  /// respeta lo que la persona eligió en su teléfono).
  double escalaCon(double escalaDelTelefono) {
    final escala = escalaDelTelefono * porcentaje / 100;
    final tope = escalaDelTelefono > escalaMaxima
        ? escalaDelTelefono
        : escalaMaxima;
    return escala > tope ? tope : escala;
  }
}
