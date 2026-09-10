import '../../domain/models/seleccion_plantilla_info.dart';
import '../../domain/repositories/repositorio_seleccion_plantilla.dart';

class ObtenerSeleccionPlantilla {
  final RepositorioSeleccionPlantilla _repositorio;

  const ObtenerSeleccionPlantilla(this._repositorio);

  Future<SeleccionPlantillaInfo> call(String uid) {
    return _repositorio.obtenerSeleccionPlantilla(uid);
  }
}
