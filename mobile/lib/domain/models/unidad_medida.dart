import 'tipo_unidad.dart';

// ═════════════════════════════════════════════════════════════════════════
// UnidadesMedida
// ═════════════════════════════════════════════════════════════════════════
// COMPATIBILIDAD — NO USAR en código nuevo.
//
// Este dominio será reemplazado por ModoVenta / FamiliaUnidad /
// CantidadBase / Dinero / ReglaVentaMedida (
// features/productos/domain/models). Se conserva únicamente porque la UI
// actual y la persistencia del catálogo aún lo consumen.
//
// USO PENDIENTE QUE IMPIDE BORRARLO:
//   - lib/features/negocio/presentation/widgets/paso_catalogo.dart  (UI)
//   - lib/features/negocio/presentation/providers/configuracion_negocio_provider.dart
//   - lib/features/negocio/data/negocio_repository.dart (serialización
//     Firestore de unitsMedida)
//
// Las cantidades comerciales se guardan en `fraccionesPermitidas` de una
// unidad base. Por ejemplo, "500 g" es el valor 500 de la base "g", no una
// unidad independiente.
// ═════════════════════════════════════════════════════════════════════════

class UnidadesMedida {
  UnidadesMedida._();

  static const Map<String, List<UnidadInfo>> porRubro = {
    'Bodega': [
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1'],
      ),
      UnidadInfo(
        nombre: 'Botella',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['250', '500', '625', '650', '1000', '1500', '2000', '2500', '3000'],
      ),
      UnidadInfo(
        nombre: 'Lata',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['170', '355', '400'],
      ),
      UnidadInfo(
        nombre: 'Bolsa',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1'],
      ),
      UnidadInfo(
        nombre: 'Caja',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['6', '12', '24'],
      ),
      UnidadInfo(
        nombre: 'Paquete',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['6', '12', '24'],
      ),
      UnidadInfo(
        nombre: 'g',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['100', '250', '500', '750', '1000'],
      ),
      UnidadInfo(
        nombre: 'kg',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1', '1.5', '2', '5'],
      ),
      UnidadInfo(
        nombre: 'ml',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['250', '500', '625', '650', '750', '1000', '1500', '2000', '2500', '3000'],
      ),
      UnidadInfo(
        nombre: 'L',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1', '1.5', '2', '2.5', '3', '5', '20'],
      ),
    ],

    'Restaurante': [
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1'],
      ),
      UnidadInfo(
        nombre: 'Porción',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.125', '0.25', '0.5', '1'],
      ),
      UnidadInfo(
        nombre: 'ml',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['250', '500'],
      ),
      UnidadInfo(
        nombre: 'L',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1'],
      ),
      UnidadInfo(nombre: 'Vaso', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Botella', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Lata', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Jarra', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Plato', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Combo', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Bandeja', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Caja', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Paquete', tipo: TipoUnidad.entera),
    ],

    'Ropa': [
      UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Par', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Conjunto', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Paquete', tipo: TipoUnidad.entera),
    ],

    'Accesorios y regalos': [
      UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Par', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Juego', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Set', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Paquete', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Caja', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Bolsa', tipo: TipoUnidad.entera),
    ],

    'Belleza y cuidado personal': [
      UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Set', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Paquete', tipo: TipoUnidad.entera),
      UnidadInfo(
        nombre: 'g',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['10', '30', '50', '100', '250', '500'],
      ),
      UnidadInfo(
        nombre: 'kg',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1'],
      ),
      UnidadInfo(
        nombre: 'ml',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: [
          '30',
          '50',
          '100',
          '120',
          '200',
          '250',
          '500',
          '750',
        ],
      ),
      UnidadInfo(
        nombre: 'L',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1'],
      ),
      UnidadInfo(nombre: 'Frasco', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Botella', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Pote', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Tubo', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Sachet', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Spray', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Caja', tipo: TipoUnidad.entera),
    ],

    'Otros': [
      UnidadInfo(nombre: 'Unidad', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Par', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Juego', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Set', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Paquete', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Caja', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Bolsa', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Botella', tipo: TipoUnidad.entera),
      UnidadInfo(nombre: 'Frasco', tipo: TipoUnidad.entera),
    ],
  };

  /// Fracciones comunes para botones rápidos — igual que tu Kotlin.
  static const List<String> fracciones = ['1/8', '1/4', '1/2', '3/4'];

  /// Equivale a `UnidadesMedida.obtener(rubro)`.
  static List<UnidadInfo> obtener(String rubro) {
    final rubroPreset = rubro == 'Farmacia' || rubro == 'Ferretería'
        ? 'Otros'
        : rubro;
    return porRubro[rubroPreset] ?? porRubro['Otros']!;
  }

  /// Equivale a `UnidadesMedida.fraccionADecimal(fraccion)`.
  static double fraccionADecimal(String fraccion) {
    switch (fraccion) {
      case '1/8':
        return 0.125;
      case '1/4':
        return 0.25;
      case '1/2':
        return 0.5;
      case '3/4':
        return 0.75;
      default:
        return 1.0;
    }
  }
}
