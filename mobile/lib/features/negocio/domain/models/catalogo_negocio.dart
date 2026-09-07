import '../../../../domain/models/tipo_unidad.dart';

class CatalogoNegocio {
  final String rubro;
  final List<String> categorias;
  final List<UnidadInfo> unidadesMedida;
  final Map<String, dynamic> configuracionInicial;

  CatalogoNegocio({
    required this.rubro,
    required List<String> categorias,
    required List<UnidadInfo> unidadesMedida,
    Map<String, dynamic> configuracionInicial = const {},
  }) : categorias = List.unmodifiable(categorias),
       unidadesMedida = List.unmodifiable(
         unidadesMedida.map(
           (unidad) => UnidadInfo(
             nombre: unidad.nombre,
             tipo: unidad.tipo,
             fraccionesPermitidas: List.unmodifiable(
               unidad.fraccionesPermitidas,
             ),
             esOpcional: unidad.esOpcional,
           ),
         ),
       ),
       configuracionInicial = Map.unmodifiable(configuracionInicial);
}
