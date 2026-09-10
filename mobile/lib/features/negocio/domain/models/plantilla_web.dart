enum PlantillaWeb {
  cristal,
  galeria,
  neon,
  sabroso;

  String get valorPersistencia => name;

  static PlantillaWeb? desdePersistencia(Object? valor) {
    if (valor is! String) return null;

    return switch (valor.trim()) {
      'cristal' => PlantillaWeb.cristal,
      'galeria' => PlantillaWeb.galeria,
      'neon' => PlantillaWeb.neon,
      'sabroso' => PlantillaWeb.sabroso,
      _ => null,
    };
  }
}
