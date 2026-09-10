import '../models/progreso_configuracion.dart';

abstract interface class RepositorioProgresoConfiguracion {
  Future<ProgresoConfiguracion> obtenerProgresoConfiguracion(String uid);

  Future<void> guardarRubro(String uid, String rubro);

  Future<void> sincronizarProgresoReconstruido(
    String uid, {
    required bool setupComplete,
    required bool confirmarProductos,
  });
}
