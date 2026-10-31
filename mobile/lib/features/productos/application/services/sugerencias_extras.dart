// ═════════════════════════════════════════════════════════════════════════
// SugerenciasExtras
// ═════════════════════════════════════════════════════════════════════════
// Los extras de ejemplo que se ofrecen según el rubro: botones que se tocan
// para agregarlos. Son solo AYUDA: el vendedor escribe los suyos y el
// sistema nunca impone nada. Precio en céntimos enteros (0 = gratis).
// Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
class ExtraSugerido {
  const ExtraSugerido(this.nombre, [this.precioCentavos = 0]);

  final String nombre;
  final int precioCentavos;
}

class SugerenciasExtras {
  SugerenciasExtras._();

  static const _otros = [ExtraSugerido('Mica', 1500)];

  static const _porRubro = <String, List<ExtraSugerido>>{
    'Ropa': [ExtraSugerido('Bordado', 800)],
    'Bodega': [ExtraSugerido('Bolsa extra', 50)],
    'Restaurante': [
      ExtraSugerido('Con ají'),
      ExtraSugerido('Papas', 600),
      ExtraSugerido('Ensalada', 400),
    ],
    'Accesorios y regalos': [ExtraSugerido('Grabado', 1000)],
    'Belleza y cuidado personal': [ExtraSugerido('Envoltura de regalo')],
  };

  /// Las sugerencias del rubro; los rubros desconocidos o antiguos usan las
  /// de "Otros".
  static List<ExtraSugerido> de(String rubro) => _porRubro[rubro] ?? _otros;
}
