import '../../../../productos/domain/models/familia_unidad.dart';

/// Nombre legible de una familia de unidades.
String nombreFamiliaMedida(FamiliaUnidad familia) => switch (familia) {
  FamiliaUnidad.conteo => 'Conteo',
  FamiliaUnidad.peso => 'Peso',
  FamiliaUnidad.volumen => 'Volumen',
  FamiliaUnidad.longitud => 'Longitud',
  FamiliaUnidad.area => 'Área',
};
