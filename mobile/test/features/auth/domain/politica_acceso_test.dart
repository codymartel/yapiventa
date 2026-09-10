import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/politica_acceso.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_negocio.dart';
import 'package:mobile/features/negocio/domain/models/progreso_configuracion.dart';
import 'package:mobile/features/negocio/domain/models/plantilla_web.dart';

void main() {
  const rutasDelFlujo = {
    RutasAcceso.dashboard,
    RutasAcceso.rubro,
    RutasAcceso.negocio,
    RutasAcceso.productos,
    RutasAcceso.plantilla,
  };

  final casos = <EtapaConfiguracion, Set<String>>{
    EtapaConfiguracion.rubro: {RutasAcceso.dashboard, RutasAcceso.rubro},
    EtapaConfiguracion.negocio: {
      RutasAcceso.dashboard,
      RutasAcceso.rubro,
      RutasAcceso.negocio,
    },
    EtapaConfiguracion.productos: {
      RutasAcceso.dashboard,
      RutasAcceso.rubro,
      RutasAcceso.negocio,
      RutasAcceso.productos,
    },
    EtapaConfiguracion.plantilla: rutasDelFlujo,
    EtapaConfiguracion.completa: rutasDelFlujo,
  };

  for (final caso in casos.entries) {
    test('permite solo las rutas habilitadas en etapa ${caso.key.name}', () {
      final progreso = _progresoEn(caso.key);

      for (final ruta in rutasDelFlujo) {
        expect(
          PoliticaAcceso.permite(ruta, progreso),
          caso.value.contains(ruta),
          reason: 'Resultado inesperado para $ruta en ${caso.key.name}',
        );
      }
      expect(PoliticaAcceso.permite('/ruta-desconocida', progreso), isFalse);
      expect(PoliticaAcceso.permite(RutasAcceso.acceso, progreso), isFalse);
      expect(
        PoliticaAcceso.permite(RutasAcceso.verificacion, progreso),
        isFalse,
      );
    });
  }

  test('traduce cada etapa a su ruta de continuación', () {
    expect(PoliticaAcceso.rutaDe(EtapaConfiguracion.rubro), RutasAcceso.rubro);
    expect(
      PoliticaAcceso.rutaDe(EtapaConfiguracion.negocio),
      RutasAcceso.negocio,
    );
    expect(
      PoliticaAcceso.rutaDe(EtapaConfiguracion.productos),
      RutasAcceso.productos,
    );
    expect(
      PoliticaAcceso.rutaDe(EtapaConfiguracion.plantilla),
      RutasAcceso.plantilla,
    );
    expect(
      PoliticaAcceso.rutaDe(EtapaConfiguracion.completa),
      RutasAcceso.dashboard,
    );
  });
}

ProgresoConfiguracion _progresoEn(EtapaConfiguracion etapa) {
  final rubroCompleto = etapa != EtapaConfiguracion.rubro;
  final negocioCompleto = {
    EtapaConfiguracion.productos,
    EtapaConfiguracion.plantilla,
    EtapaConfiguracion.completa,
  }.contains(etapa);
  final productosCompletos = {
    EtapaConfiguracion.plantilla,
    EtapaConfiguracion.completa,
  }.contains(etapa);

  return ProgresoConfiguracion(
    catalogo: CatalogoNegocio(
      rubro: rubroCompleto ? 'Bodega' : '',
      categorias: const [],
      unidadesMedida: const [],
    ),
    slug: '',
    plantilla: etapa == EtapaConfiguracion.completa
        ? PlantillaWeb.cristal
        : null,
    plantillaProvieneDeCampoOficial: etapa == EtapaConfiguracion.completa,
    rubroCompleto: rubroCompleto,
    negocioCompleto: negocioCompleto,
    productosCompletos: productosCompletos,
    setupCompletePersistido: etapa == EtapaConfiguracion.completa,
    productosConfirmadosPersistidos: etapa == EtapaConfiguracion.completa,
  );
}
