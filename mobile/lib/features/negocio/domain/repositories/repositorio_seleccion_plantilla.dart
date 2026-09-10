import '../models/plantilla_web.dart';
import '../models/seleccion_plantilla_info.dart';

abstract interface class RepositorioSeleccionPlantilla {
  Future<SeleccionPlantillaInfo> obtenerSeleccionPlantilla(String uid);

  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla);
}
