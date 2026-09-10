import '../../negocio/domain/models/progreso_configuracion.dart';

abstract final class RutasAcceso {
  static const acceso = '/';
  static const verificacion = '/verificar-correo';
  static const dashboard = '/home';
  static const rubro = '/elegir-rubro';
  static const negocio = '/configurar-negocio';
  static const productos = '/productos';
  static const plantilla = '/elegir-plantilla';
}

abstract final class PoliticaAcceso {
  static bool permite(String ruta, ProgresoConfiguracion progreso) {
    return switch (ruta) {
      RutasAcceso.dashboard => true,
      RutasAcceso.rubro => true,
      RutasAcceso.negocio => progreso.rubroCompleto,
      RutasAcceso.productos => progreso.negocioCompleto,
      RutasAcceso.plantilla => progreso.productosCompletos,
      _ => false,
    };
  }

  static String rutaDe(EtapaConfiguracion etapa) {
    return switch (etapa) {
      EtapaConfiguracion.rubro => RutasAcceso.rubro,
      EtapaConfiguracion.negocio => RutasAcceso.negocio,
      EtapaConfiguracion.productos => RutasAcceso.productos,
      EtapaConfiguracion.plantilla => RutasAcceso.plantilla,
      EtapaConfiguracion.completa => RutasAcceso.dashboard,
    };
  }
}
