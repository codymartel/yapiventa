/// Bloquea un cambio de rubro porque productos existentes apuntan a categorías
/// o unidades que desaparecerían al sustituir el catálogo heredado.
///
/// DESTINO: capa de datos. La captura la capa de presentación para explicar el
/// bloqueo en lugar de mostrar un error genérico de conexión.
class ProductosDependientesDeRubroException implements Exception {
  const ProductosDependientesDeRubroException({
    required this.categorias,
    required this.unidades,
  });

  /// Categorías del rubro anterior ausentes en el preset del rubro nuevo.
  final List<String> categorias;

  /// Unidades del rubro anterior ausentes en el preset del rubro nuevo.
  final List<String> unidades;

  String get mensaje {
    final detalles = <String>[
      if (categorias.isNotEmpty) 'categorías: ${categorias.join(', ')}',
      if (unidades.isNotEmpty) 'unidades: ${unidades.join(', ')}',
    ].join(' · ');
    return 'No se pudo cambiar de rubro: hay productos que usan categorías o '
        'unidades que desaparecerán ($detalles). '
        'Revisa esos productos antes de cambiar de rubro.';
  }

  @override
  String toString() => 'ProductosDependientesDeRubroException: $mensaje';
}
