/// Formato de presentación elegido en el formulario.
class FormatoElegido {
  const FormatoElegido({
    required this.valorBase,
    required this.familia,
    required this.unidad,
  });

  final int valorBase;

  /// Nombre de la familia ('peso', 'volumen'…) tal como se persiste.
  final String familia;

  /// Nombre de la unidad visible ('ml', 'kg'…).
  final String unidad;
}
