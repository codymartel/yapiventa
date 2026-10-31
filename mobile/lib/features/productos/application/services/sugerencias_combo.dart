// ═════════════════════════════════════════════════════════════════════════
// SugerenciasCombo
// ═════════════════════════════════════════════════════════════════════════
// La palabra con la que cada rubro llama a «varios productos en uno»: por
// dentro es siempre lo mismo (un combo), pero a una tienda de ropa le dice
// «conjunto» y a una de belleza «kit». Es solo AYUDA de lenguaje: el vendedor
// no la escribe. Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
class NombreCombo {
  const NombreCombo(this.palabra);

  /// En minúscula, para la pregunta: «¿Es un kit?».
  final String palabra;

  /// Con mayúscula inicial, para la tarjeta: «Kit · 2 productos».
  String get capitalizada => palabra[0].toUpperCase() + palabra.substring(1);
}

class SugerenciasCombo {
  SugerenciasCombo._();

  static const _combo = NombreCombo('combo');
  static const _otros = NombreCombo('pack');

  static const _porRubro = <String, NombreCombo>{
    'Restaurante': _combo,
    'Bodega': _combo,
    'Ropa': NombreCombo('conjunto'),
    'Accesorios y regalos': NombreCombo('set de regalo'),
    'Belleza y cuidado personal': NombreCombo('kit'),
  };

  /// La palabra del rubro; los rubros desconocidos o antiguos usan «pack».
  static NombreCombo de(String rubro) => _porRubro[rubro] ?? _otros;
}
