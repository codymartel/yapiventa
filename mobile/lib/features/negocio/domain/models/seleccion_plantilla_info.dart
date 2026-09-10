import 'plantilla_web.dart';

class SeleccionPlantillaInfo {
  final String slug;
  final PlantillaWeb? plantillaGuardada;
  final bool provieneDeCampoOficial;

  const SeleccionPlantillaInfo({
    required this.slug,
    required this.plantillaGuardada,
    required this.provieneDeCampoOficial,
  });
}
