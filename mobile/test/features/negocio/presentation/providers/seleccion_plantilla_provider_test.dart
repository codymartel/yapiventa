import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/application/use_cases/guardar_plantilla_web.dart';
import 'package:mobile/features/negocio/application/use_cases/obtener_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';
import 'package:mobile/features/negocio/domain/models/seleccion_plantilla_info.dart';
import 'package:mobile/features/negocio/domain/repositories/repositorio_seleccion_plantilla.dart';
import 'package:mobile/features/negocio/presentation/providers/seleccion_plantilla_provider.dart';

void main() {
  late _RepositorioSeleccionFake repositorio;
  late SeleccionPlantillaProvider provider;

  setUp(() {
    repositorio = _RepositorioSeleccionFake();
    provider = SeleccionPlantillaProvider(
      uid: 'usuario-1',
      obtenerSeleccionPlantilla: ObtenerSeleccionPlantilla(repositorio),
      guardarPlantillaWeb: GuardarPlantillaWeb(repositorio),
    );
  });

  tearDown(() => provider.dispose());

  test('comparte una lectura inicial conjunta y conserva los datos', () async {
    final primera = provider.cargar();
    final segunda = provider.cargar();

    await Future.wait([primera, segunda]);
    await provider.cargar();

    expect(repositorio.lecturas, 1);
    expect(provider.slug, 'bodega-ana');
    expect(provider.plantillaGuardada, PlantillaWeb.neon);
    expect(provider.seleccionTemporal, PlantillaWeb.neon);
    expect(provider.cambiosPendientes, isFalse);
  });

  test('seleccionar una tarjeta solo modifica memoria', () async {
    await provider.cargar();

    provider.seleccionar(PlantillaWeb.galeria);

    expect(provider.seleccionTemporal, PlantillaWeb.galeria);
    expect(provider.plantillaGuardada, PlantillaWeb.neon);
    expect(provider.cambiosPendientes, isTrue);
    expect(repositorio.escrituras, 0);
  });

  test('recargar reemplaza la seleccion con el valor persistido', () async {
    await provider.cargar();
    repositorio.info = const SeleccionPlantillaInfo(
      slug: 'bodega-ana',
      plantillaGuardada: PlantillaWeb.galeria,
      provieneDeCampoOficial: true,
    );

    await provider.recargar();

    expect(repositorio.lecturas, 2);
    expect(provider.plantillaGuardada, PlantillaWeb.galeria);
    expect(provider.seleccionTemporal, PlantillaWeb.galeria);
  });

  test(
    'no escribe una seleccion sin cambios ya guardada oficialmente',
    () async {
      await provider.cargar();

      final guardado = await provider.guardar();

      expect(guardado, isTrue);
      expect(repositorio.escrituras, 0);
      expect(repositorio.lecturas, 1);
    },
  );

  test('oficializa el fallback legado sin releer despues de guardar', () async {
    repositorio.info = const SeleccionPlantillaInfo(
      slug: 'bodega-ana',
      plantillaGuardada: PlantillaWeb.neon,
      provieneDeCampoOficial: false,
    );
    await provider.cargar();

    final guardado = await provider.guardar();

    expect(guardado, isTrue);
    expect(repositorio.escrituras, 1);
    expect(repositorio.ultimaPlantilla, PlantillaWeb.neon);
    expect(repositorio.lecturas, 1);
    expect(provider.cambiosPendientes, isFalse);
  });

  test('protege el guardado frente a una doble pulsacion', () async {
    await provider.cargar();
    provider.seleccionar(PlantillaWeb.cristal);
    repositorio.guardadoPendiente = Completer<void>();

    final primero = provider.guardar();
    final segundo = provider.guardar();

    expect(identical(primero, segundo), isTrue);
    expect(repositorio.escrituras, 1);
    repositorio.guardadoPendiente!.complete();
    expect(await primero, isTrue);
    expect(await segundo, isTrue);
    expect(provider.plantillaGuardada, PlantillaWeb.cristal);
    expect(repositorio.lecturas, 1);
  });

  test('ignora otra seleccion mientras guarda', () async {
    await provider.cargar();
    provider.seleccionar(PlantillaWeb.cristal);
    repositorio.guardadoPendiente = Completer<void>();

    final guardado = provider.guardar();
    provider.seleccionar(PlantillaWeb.sabroso);
    repositorio.guardadoPendiente!.complete();

    expect(await guardado, isTrue);
    expect(provider.plantillaGuardada, PlantillaWeb.cristal);
    expect(provider.seleccionTemporal, PlantillaWeb.cristal);
  });

  test(
    'un error conserva la seleccion temporal y permite reintentar',
    () async {
      await provider.cargar();
      provider.seleccionar(PlantillaWeb.sabroso);
      repositorio.errorGuardado = Exception('sin conexion');

      final guardado = await provider.guardar();

      expect(guardado, isFalse);
      expect(provider.seleccionTemporal, PlantillaWeb.sabroso);
      expect(provider.plantillaGuardada, PlantillaWeb.neon);
      expect(provider.cambiosPendientes, isTrue);
      expect(provider.errorMessage, contains('sin conexion'));
      expect(repositorio.lecturas, 1);
      expect(repositorio.escrituras, 1);
    },
  );
}

class _RepositorioSeleccionFake implements RepositorioSeleccionPlantilla {
  int lecturas = 0;
  int escrituras = 0;
  Object? errorGuardado;
  Completer<void>? guardadoPendiente;
  PlantillaWeb? ultimaPlantilla;
  SeleccionPlantillaInfo info = const SeleccionPlantillaInfo(
    slug: 'bodega-ana',
    plantillaGuardada: PlantillaWeb.neon,
    provieneDeCampoOficial: true,
  );

  @override
  Future<SeleccionPlantillaInfo> obtenerSeleccionPlantilla(String uid) async {
    lecturas++;
    return info;
  }

  @override
  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla) async {
    escrituras++;
    ultimaPlantilla = plantilla;
    final pendiente = guardadoPendiente;
    if (pendiente != null) await pendiente.future;
    final error = errorGuardado;
    if (error != null) throw error;
  }
}
