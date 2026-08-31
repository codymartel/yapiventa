import 'tipo_unidad.dart';

// ═════════════════════════════════════════════════════════════════════════
// UnidadesMedida
// ═════════════════════════════════════════════════════════════════════════
// Migración de tu `object UnidadesMedida`. Mismos rubros y valores que tu
// Kotlin, con estos cambios respecto al original:
//
//   1. Se QUITÓ "Tecnología" (descartado en la investigación de mercado)
//   2. Se AGREGÓ "Ferretería" — investigado con fuentes reales (INVY
//      Perú, OKFAC, Ferretero.pe)
//   3. TODAS las `fraccionesPermitidas` de tipo FRACCIONARIA ahora usan
//      decimales consistentes (0.25, 0.5, 1.5, etc.) en vez de mezclar
//      fracciones ("1/2") y decimales ("1.5") como pasaba en el Kotlin
//      original (ej. el "kg" de Bodega tenía ["1/4","1/2","3/4","1",
//      "1.5","2"] — mezcla que detectamos y corregimos aquí).
//      Esto es solo el catálogo BASE de valores rápidos — el usuario
//      igual puede escribir en fracción si quiere, eso lo maneja
//      ValidadorCantidad, que convierte cualquier fracción a decimal
//      antes de guardarla. Ver validador_cantidad.dart.
// ═════════════════════════════════════════════════════════════════════════

class UnidadesMedida {
  UnidadesMedida._();

  static const Map<String, List<UnidadInfo>> porRubro = {
    'Bodega': [
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '3', '6', '12'],
      ),
      UnidadInfo(
        nombre: 'kg',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '0.75', '1', '1.5', '2'],
      ),
      UnidadInfo(
        nombre: 'g',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['100', '250', '500', '750'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Litro (L)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1', '2'],
      ),
      UnidadInfo(
        nombre: 'ml',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['250', '500', '750'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Paquete',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '3'],
      ),
      UnidadInfo(
        nombre: 'Docena',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
      ),
      UnidadInfo(
        nombre: 'Arroba (@)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Saco',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '5'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Plancha',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
        esOpcional: true,
      ),
    ],

    'Farmacia': [
      UnidadInfo(
        nombre: 'Pastilla',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '5', '10'],
      ),
      UnidadInfo(
        nombre: 'Blíster',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '3'],
      ),
      UnidadInfo(
        nombre: 'Caja',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
      ),
      UnidadInfo(
        nombre: 'Frasco',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
      ),
      UnidadInfo(
        nombre: 'ml',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['5', '10', '20', '50', '100'],
      ),
      UnidadInfo(
        nombre: 'mg',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['250', '500'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'g',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1', '5', '10'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Sachet',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '5'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '3'],
      ),
    ],

    'Restaurante': [
      UnidadInfo(
        nombre: 'Plato',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
      ),
      UnidadInfo(
        nombre: 'Porción',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
      ),
      UnidadInfo(
        nombre: 'Jarra',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
      ),
      UnidadInfo(
        nombre: 'Vaso',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.5', '1'],
      ),
      UnidadInfo(
        nombre: 'Copa',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.5', '1'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '3'],
      ),
      UnidadInfo(
        nombre: 'Combo',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
      ),
      UnidadInfo(
        nombre: 'Dúo',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1'],
        esOpcional: true,
      ),
    ],

    'Ropa': [
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '3'],
      ),
      UnidadInfo(
        nombre: 'Par',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
      ),
      UnidadInfo(
        nombre: 'Set',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
        esOpcional: true,
      ),
    ],

    'Ferretería': [
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '5', '10', '20'],
      ),
      UnidadInfo(
        nombre: 'kg',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1', '2', '5'],
      ),
      UnidadInfo(
        nombre: 'Metro (m)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.5', '1', '2', '5', '10'],
      ),
      UnidadInfo(
        nombre: 'Caja',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '5'],
      ),
      UnidadInfo(
        nombre: 'Litro (L)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1', '4'],
      ),
      UnidadInfo(
        nombre: 'Rollo',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Galón (gal)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
        esOpcional: true,
      ),
    ],

    'Otros': [
      UnidadInfo(
        nombre: 'Unidad',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '3', '6', '12'],
      ),
      UnidadInfo(
        nombre: 'kg',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '0.75', '1', '2'],
      ),
      UnidadInfo(
        nombre: 'Litro (L)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1', '2'],
      ),
      UnidadInfo(
        nombre: 'Metro (m)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1', '2', '5'],
      ),
      UnidadInfo(
        nombre: 'Docena',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
      ),
      UnidadInfo(
        nombre: 'Par',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
      ),
      UnidadInfo(
        nombre: 'g',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['100', '250', '500'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'ml',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['250', '500', '750'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Galón (gal)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Cilindro',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'cm',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['10', '20', '50', '100'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Pulgada (in)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Pie',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.5', '1', '2'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'm²',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['1', '2', '5', '10'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Ciento',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Millar',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Paquete',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2', '3'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Saco',
        tipo: TipoUnidad.entera,
        fraccionesPermitidas: ['1', '2'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Arroba (@)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
        esOpcional: true,
      ),
      UnidadInfo(
        nombre: 'Tonelada (t)',
        tipo: TipoUnidad.fraccionaria,
        fraccionesPermitidas: ['0.25', '0.5', '1'],
        esOpcional: true,
      ),
    ],
  };

  /// Fracciones comunes para botones rápidos — igual que tu Kotlin.
  static const List<String> fracciones = ['1/8', '1/4', '1/2', '3/4'];

  /// Equivale a `UnidadesMedida.obtener(rubro)`.
  static List<UnidadInfo> obtener(String rubro) {
    return porRubro[rubro] ?? porRubro['Otros']!;
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