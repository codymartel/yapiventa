/// Escala de espacios y tamaños de letra del panel. Solo estos valores: así
/// PC y celular comparten el mismo ritmo y no aparecen 10, 14 o 18 sueltos.
class AppSpacing {
  AppSpacing._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Alto mínimo táctil (44 en iOS, 48 en Android: se usa 44 y se expande).
  static const double minTactil = 44;
}

/// Tamaños de letra permitidos. Nada por debajo de [chico] en texto que el
/// vendedor lee; [grande] es para el título del login.
class AppFontSize {
  AppFontSize._();

  static const double chico = 12;
  static const double normal = 13;
  static const double cuerpo = 14;
  static const double subtitulo = 16;
  static const double titulo = 20;
  static const double grande = 28;
}
