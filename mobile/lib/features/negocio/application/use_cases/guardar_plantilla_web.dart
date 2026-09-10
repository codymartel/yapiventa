import '../../domain/models/plantilla_web.dart';
import '../../domain/repositories/repositorio_seleccion_plantilla.dart';

class GuardarPlantillaWeb {
  final RepositorioSeleccionPlantilla _repositorio;

  const GuardarPlantillaWeb(this._repositorio);

  Future<void> call(String uid, PlantillaWeb plantilla) {
    return _repositorio.guardarPlantillaWeb(uid, plantilla);
  }
}
