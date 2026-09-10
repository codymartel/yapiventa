import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/application/use_cases/guardar_plantilla_web.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/seleccion_plantilla_info.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_seleccion_plantilla.dart';

void main() {
  test('los casos de uso delegan datos tipados al contrato', () async {
    final repositorio = _RepositorioSeleccionFake();
    final obtener = ObtenerSeleccionPlantilla(repositorio);
    final guardar = GuardarPlantillaWeb(repositorio);

    final info = await obtener('usuario-1');
    await guardar('usuario-1', PlantillaWeb.sabroso);

    expect(info.slug, 'bodega-ana');
    expect(repositorio.uidLeido, 'usuario-1');
    expect(repositorio.uidGuardado, 'usuario-1');
    expect(repositorio.plantillaGuardada, PlantillaWeb.sabroso);
  });
}

class _RepositorioSeleccionFake implements RepositorioSeleccionPlantilla {
  String? uidLeido;
  String? uidGuardado;
  PlantillaWeb? plantillaGuardada;

  @override
  Future<SeleccionPlantillaInfo> obtenerSeleccionPlantilla(String uid) async {
    uidLeido = uid;
    return const SeleccionPlantillaInfo(
      slug: 'bodega-ana',
      plantillaGuardada: PlantillaWeb.neon,
      provieneDeCampoOficial: true,
    );
  }

  @override
  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla) async {
    uidGuardado = uid;
    plantillaGuardada = plantilla;
  }
}
