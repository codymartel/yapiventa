import 'application/use_cases/guardar_plantilla_web.dart';
import 'application/use_cases/obtener_seleccion_plantilla.dart';
import 'data/negocio_repository.dart';

class SeleccionPlantillaDependencies {
  final ObtenerSeleccionPlantilla obtenerSeleccionPlantilla;
  final GuardarPlantillaWeb guardarPlantillaWeb;

  const SeleccionPlantillaDependencies({
    required this.obtenerSeleccionPlantilla,
    required this.guardarPlantillaWeb,
  });

  factory SeleccionPlantillaDependencies.production() {
    final repositorio = NegocioRepository();
    return SeleccionPlantillaDependencies.fromRepository(repositorio);
  }

  factory SeleccionPlantillaDependencies.fromRepository(
    NegocioRepository repositorio,
  ) {
    return SeleccionPlantillaDependencies(
      obtenerSeleccionPlantilla: ObtenerSeleccionPlantilla(repositorio),
      guardarPlantillaWeb: GuardarPlantillaWeb(repositorio),
    );
  }
}
