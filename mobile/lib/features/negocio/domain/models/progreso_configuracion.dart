import 'catalogo_negocio.dart';
import 'plantilla_web.dart';

enum EtapaConfiguracion { rubro, negocio, productos, plantilla, completa }

class ProgresoConfiguracion {
  final CatalogoNegocio catalogo;
  final String slug;
  final PlantillaWeb? plantilla;
  final bool plantillaProvieneDeCampoOficial;
  final bool rubroCompleto;
  final bool negocioCompleto;
  final bool productosCompletos;
  final bool setupCompletePersistido;
  final bool productosConfirmadosPersistidos;

  const ProgresoConfiguracion({
    required this.catalogo,
    required this.slug,
    required this.plantilla,
    required this.plantillaProvieneDeCampoOficial,
    required this.rubroCompleto,
    required this.negocioCompleto,
    required this.productosCompletos,
    required this.setupCompletePersistido,
    required this.productosConfirmadosPersistidos,
  });

  bool get plantillaCompleta =>
      productosCompletos && slug.trim().isNotEmpty && plantilla != null;
  bool get completo =>
      rubroCompleto &&
      negocioCompleto &&
      productosCompletos &&
      plantillaCompleta;

  EtapaConfiguracion get siguiente => !rubroCompleto
      ? EtapaConfiguracion.rubro
      : !negocioCompleto
      ? EtapaConfiguracion.negocio
      : !productosCompletos
      ? EtapaConfiguracion.productos
      : !plantillaCompleta
      ? EtapaConfiguracion.plantilla
      : EtapaConfiguracion.completa;

  ProgresoConfiguracion copyWith({
    bool? setupCompletePersistido,
    bool? productosConfirmadosPersistidos,
  }) {
    return ProgresoConfiguracion(
      catalogo: catalogo,
      slug: slug,
      plantilla: plantilla,
      plantillaProvieneDeCampoOficial: plantillaProvieneDeCampoOficial,
      rubroCompleto: rubroCompleto,
      negocioCompleto: negocioCompleto,
      productosCompletos: productosCompletos,
      setupCompletePersistido:
          setupCompletePersistido ?? this.setupCompletePersistido,
      productosConfirmadosPersistidos:
          productosConfirmadosPersistidos ??
          this.productosConfirmadosPersistidos,
    );
  }
}
