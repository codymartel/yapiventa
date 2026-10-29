import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_global.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';

import '../../domain/models/familia_unidad.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// VistaLegacyProducto
// ═════════════════════════════════════════════════════════════════════════
// Deriva los campos de la "vista legacy" (precio, stock, unidadMedidaNombre,
// fraccionesSeleccionadas) desde el modelo de venta del [Producto]. Los lee
// la tienda pública y el formulario viejo, y los escribe SOLO
// ProductoFirestoreMapper: siempre se DERIVAN, nunca al revés.
//
//   ModoVenta.presentacion
//     precio              = precioCentavos / 100 (precio de UNA presentación)
//     stock               = stock (conteo de presentaciones, tal cual)
//     unidadMedidaNombre  = nombre de la presentación del catálogo global
//                           ("Botella"); si el producto es legacy sin
//                           presentacionId, la etiqueta heredada.
//     fracciones          = etiqueta del formato ("625 ml"); si no hay
//                           formato conocido, se conserva la lista leída.
//   ModoVenta.medida
//     precio              = precio por UNA unidad visual, con piso:
//                           (precioCentavos × factorBase) ~/ referencia
//     stock               = stockBase ~/ factorBase, con piso (nunca se
//                           promete más stock del real)
//     unidadMedidaNombre  = unidad visual (kg, L...)
//     fracciones          = [] (la web solo muestra la etiqueta)
//
// Puro (sin Firestore, sin providers): importa el registro cerrado de
// unidades y el catálogo global solo para derivar nombres y etiquetas.
// ═════════════════════════════════════════════════════════════════════════
abstract final class VistaLegacyProducto {
  static double precio(Producto producto) {
    if (!producto.esPorMedida) {
      return centavosASoles(producto.precioCentavos);
    }
    final precio = precioPorUnidadVisual(
      producto.precioCentavos,
      producto.cantidadReferenciaBase,
      factorBase(producto.medidaUnidad),
    );
    return centavosASoles(precio);
  }

  static int stock(Producto producto) {
    if (!producto.esPorMedida) return producto.stock;
    final stockBase = producto.stockBase;
    if (stockBase == null) return producto.stock;
    final factor = factorBase(producto.medidaUnidad);
    if (factor <= 0) return producto.stock;
    // Piso: la web vende unidades visuales enteras; nunca se promete más
    // stock del que realmente hay.
    return stockBase ~/ factor;
  }

  static String unidad(Producto producto) {
    if (!producto.esPorMedida) {
      if (producto.presentacionId.isNotEmpty) {
        final nombre = _nombrePresentacion(producto.presentacionId);
        if (nombre != null) return nombre;
        // Presentación propia del negocio (Jaba): no está en el catálogo global.
        if (producto.presentacionNombre.isNotEmpty) {
          return producto.presentacionNombre;
        }
      }
      return producto.etiquetaUnidad;
    }
    return producto.medidaUnidad;
  }

  static List<String> fracciones(Producto producto) {
    if (producto.esPorMedida) return const [];
    // Con modelos el tamaño real está en cada fila: se listan los distintos.
    if (producto.tieneModelos) return _formatosDeFilas(producto);
    final etiqueta = _etiquetaFormato(
      producto.formatoValorBase,
      producto.formatoFamilia,
      producto.formatoUnidad,
    );
    if (etiqueta != null) return [etiqueta];
    // Sin formato conocido (productos legacy leídos): se conserva la lista.
    return producto.fraccionesSeleccionadas;
  }

  static List<String> _formatosDeFilas(Producto producto) {
    final etiquetas = <String>[];
    for (final modelo in producto.modelos) {
      for (final fila in modelo.filas) {
        final etiqueta = _etiquetaFormato(
          fila.formatoValorBase,
          fila.formatoFamilia,
          fila.formatoUnidad,
        );
        if (etiqueta != null && !etiquetas.contains(etiqueta)) {
          etiquetas.add(etiqueta);
        }
      }
    }
    return etiquetas;
  }

  // ── Aritmética entera ─────────────────────────────────────────────────

  /// Precio por UNA unidad visual, en céntimos, con piso. Si la referencia
  /// no es un múltiplo exacto de la unidad visual, el piso garantiza que
  /// nunca se cobre más de lo correcto por unidad.
  static int precioPorUnidadVisual(
    int centavos,
    int referenciaBase,
    int factorBase,
  ) {
    if (referenciaBase <= 0) return centavos;
    if (factorBase <= 0) return centavos;
    return (centavos * factorBase) ~/ referenciaBase;
  }

  static double centavosASoles(int centavos) => centavos / 100;

  static int solesACentavos(Object? precio) {
    final soles = (precio as num?)?.toDouble() ?? 0;
    return (soles * 100).round();
  }

  // ── Registro cerrado (puro, sin I/O) ──────────────────────────────────

  static int factorBase(String nombreUnidad) {
    final unidad = _unidadRegistrada(nombreUnidad);
    return unidad?.factorBase ?? 0;
  }

  /// Presentación del catálogo global cuyo nombre coincide (sin distinguir
  /// mayúsculas) con la etiqueta legacy. null si no coincide con ninguna.
  static String? presentacionIdDeNombre(String nombre) {
    if (nombre.isEmpty) return null;
    for (final entrada in CatalogoVentaGlobal.nombres.entries) {
      if (entrada.value.toLowerCase() == nombre.toLowerCase()) {
        return entrada.key;
      }
    }
    return null;
  }

  static UnidadRegistrada? _unidadRegistrada(String nombreUnidad) {
    if (nombreUnidad.isEmpty) return null;
    for (final familia in FamiliaUnidad.values) {
      for (final unidad in RegistroUnidades.unidadesDe(familia)) {
        if (unidad.nombre == nombreUnidad) return unidad;
      }
    }
    return null;
  }

  static String? _nombrePresentacion(String presentacionId) {
    try {
      return CatalogoVentaGlobal.nombreDe(presentacionId);
    } catch (_) {
      return null;
    }
  }

  static String? _etiquetaFormato(
    int valorBase,
    FamiliaUnidad? familia,
    String unidadNombre,
  ) {
    if (valorBase <= 0 || familia == null || unidadNombre.isEmpty) return null;
    final unidad = _unidadRegistrada(unidadNombre);
    if (unidad == null) return null;
    try {
      return FormatoPresentacion(
        valorBase: valorBase,
        familia: familia,
        unidadVisible: unidad,
      ).etiqueta;
    } catch (_) {
      return null;
    }
  }
}
