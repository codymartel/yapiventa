// ═════════════════════════════════════════════════════════════════════════
// SugerenciasModelos
// ═════════════════════════════════════════════════════════════════════════
// Las palabras de ejemplo que se ofrecen según el rubro cuando el vendedor
// nombra "lo que cambia" de su producto. Son solo AYUDA en gris y botones:
// el vendedor escribe la palabra que quiera y el sistema nunca impone
// "Color". Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
class SugerenciaModelos {
  const SugerenciaModelos({
    required this.ejemplo,
    required this.palabras,
    required this.tituloFilas,
  });

  /// "colores, estilos o diseños": completa "¿viene en distintos …?".
  final String ejemplo;

  /// Botones de sugerencia para nombrar lo que cambia.
  final List<String> palabras;

  /// Título de las filas "Se vende en" que se propone al empezar.
  final String tituloFilas;
}

class SugerenciasModelos {
  SugerenciasModelos._();

  /// Palabras para el título de las filas, para elegir sin escribir.
  static const List<String> titulosFilas = [
    'Talla',
    'Número',
    'Tamaño',
    'Formato',
    'Frasco',
  ];

  static const _otros = SugerenciaModelos(
    ejemplo: 'colores, modelos o tipos',
    palabras: ['Color', 'Modelo', 'Tipo'],
    tituloFilas: 'Tamaño',
  );

  static const _porRubro = <String, SugerenciaModelos>{
    'Ropa': SugerenciaModelos(
      ejemplo: 'colores, estilos o diseños',
      palabras: ['Color', 'Estilo', 'Diseño'],
      tituloFilas: 'Talla',
    ),
    'Bodega': SugerenciaModelos(
      ejemplo: 'sabores o marcas',
      palabras: ['Sabor', 'Marca', 'Tipo'],
      tituloFilas: 'Formato',
    ),
    'Restaurante': SugerenciaModelos(
      ejemplo: 'sabores o tipos',
      palabras: ['Sabor', 'Tipo', 'Estilo'],
      tituloFilas: 'Tamaño',
    ),
    'Accesorios y regalos': SugerenciaModelos(
      ejemplo: 'colores, materiales o diseños',
      palabras: ['Color', 'Material', 'Diseño'],
      tituloFilas: 'Tamaño',
    ),
    'Belleza y cuidado personal': SugerenciaModelos(
      ejemplo: 'aromas o tonos',
      palabras: ['Aroma', 'Tono', 'Fragancia'],
      tituloFilas: 'Formato',
    ),
  };

  /// La sugerencia del rubro; los rubros desconocidos o antiguos usan la de
  /// "Otros".
  static SugerenciaModelos de(String rubro) => _porRubro[rubro] ?? _otros;
}
