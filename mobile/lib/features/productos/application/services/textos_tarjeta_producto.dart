import '../../../negocio/domain/models/catalogo_venta/catalogo_venta_global.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/producto.dart';
import 'calculo_combo.dart';
import 'cantidades_tipicas.dart';
import 'entrada_numerica.dart';
import 'lectura_unidades_producto.dart';
import 'totales_producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextosTarjetaProducto
// ═════════════════════════════════════════════════════════════════════════
// Los textos de precio y stock de la tarjeta del producto. Función pura, sin
// Flutter. Leen los campos NUEVOS del producto (precioCentavos, stock,
// stockBase), nunca los campos viejos precio/stock que solo deriva el mapper:
// un producto recién guardado desde el formulario no los trae.
//
// PRECIO (el que escribió el vendedor, nunca convertido):
//   - por medida   → "S/ 3.00 / ¼ kg" y, solo si la cuenta es exacta,
//                    " · S/ 12.00 / kg" (el precio por la unidad grande).
//   - presentación → "S/ 8.50 / botella (625 ml)".
//   - antiguo      → "S/ 16.50".
//   - con modelos  → "desde S/ 35.00" si los precios de las filas difieren.
// ═════════════════════════════════════════════════════════════════════════
class TextosTarjetaProducto {
  TextosTarjetaProducto._();

  static String precio(Producto producto) {
    // Un combo tiene su precio propio, sin «/ unidad» ni «desde».
    if (producto.esCombo) {
      return 'S/ ${centavosATexto(producto.precioCentavos)}';
    }
    final desde = producto.tieneModelos
        ? TotalesProducto.precioDesdeCentavos(producto.modelos)
        : producto.precioCentavos;
    final precio = 'S/ ${centavosATexto(desde)}';
    final texto = producto.esPorMedida
        ? _precioMedida(producto, desde, precio)
        : _conSufijoPresentacion(producto, precio);
    return _preciosDistintos(producto) ? 'desde $texto' : texto;
  }

  static String _conSufijoPresentacion(Producto producto, String precio) {
    final sufijo = _sufijoPresentacion(producto);
    return sufijo.isEmpty ? precio : '$precio / $sufijo';
  }

  /// true si las filas de los modelos no cuestan todas lo mismo.
  static bool _preciosDistintos(Producto producto) {
    final precios = {
      for (final modelo in producto.modelos)
        for (final fila in modelo.filas)
          if (fila.precioCentavos > 0) fila.precioCentavos,
    };
    return precios.length > 1;
  }

  /// Stock con su unidad: "16.65 kg", "12 botellas", "7 uds." o "ilimitado".
  static String stock(
    Producto producto, {
    List<Producto> conocidos = const [],
  }) {
    if (producto.esCombo) return _stockCombo(producto, conocidos);
    if (producto.esStockInfinito) return 'ilimitado';
    if (producto.tieneModelos) {
      return '${_stockSinModelos(producto)} · ${_cuantosModelos(producto)}';
    }
    return _stockSinModelos(producto);
  }

  /// «Kit · 2 productos»: la palabra del rubro y cuántos productos lleva.
  static String etiquetaCombo(Producto producto, String palabra) {
    final cantidad = producto.partes.length;
    return '$palabra · $cantidad ${cantidad == 1 ? 'producto' : 'productos'}';
  }

  /// El stock de un combo se calcula de sus partes (con los productos ya
  /// cargados): «Quedan 4 · limita: Gaseosa», «Agotado · sin Papas».
  static String _stockCombo(Producto combo, List<Producto> conocidos) {
    final resultado = CalculoCombo.calcular(combo.partes, (id) {
      for (final producto in conocidos) {
        if (producto.id == id) return producto;
      }
      return null;
    });
    if (resultado.sinDatos) return '—';
    if (resultado.ilimitado) return 'ilimitado';
    if (resultado.agotado) return 'Agotado · sin ${resultado.limita}';
    if (resultado.stock == null) return '—';
    return 'Quedan ${resultado.stock} · limita: ${resultado.limita}';
  }

  /// "2 colores", "1 aroma": cuántos modelos, con la palabra del vendedor.
  static String _cuantosModelos(Producto producto) {
    final palabra = producto.tituloModelos.trim().toLowerCase();
    final cantidad = producto.modelos.length;
    final nombre = palabra.isEmpty ? 'modelo' : palabra;
    return '$cantidad ${cantidad == 1 ? nombre : LecturaUnidadesProducto.plural(nombre)}';
  }

  static String _stockSinModelos(Producto producto) {
    if (producto.esPorMedida) {
      final base = producto.tieneModelos
          ? TotalesProducto.stockBaseTotal(producto.modelos)
          : producto.stockBase;
      final factor = LecturaUnidadesProducto.factorDe(producto.medidaUnidad);
      if (base != null && factor > 0) {
        return '${baseATextoVisual(base, factor)} ${producto.medidaUnidad}';
      }
      final unidad = producto.medidaUnidad.isEmpty
          ? 'uds.'
          : producto.medidaUnidad;
      return '${producto.stock} $unidad';
    }
    final unidades = producto.tieneModelos
        ? TotalesProducto.stockTotal(producto.modelos)
        : producto.stock;
    final nombre = _nombrePresentacion(producto);
    if (nombre == null) return '$unidades uds.';
    return '$unidades ${LecturaUnidadesProducto.plural(nombre)}';
  }

  /// Unidad propia de un producto antiguo (sin presentación ni medida);
  /// '' para los demás, porque su precio y stock ya la dicen.
  static String unidadAntigua(Producto producto) {
    if (producto.esPorMedida || producto.presentacionId.isNotEmpty) return '';
    return producto.unidadMedidaNombre;
  }

  /// "Saco" o "Saco · fracción: 1/2" de un producto antiguo; '' si no aplica.
  static String lineaUnidadAntigua(Producto producto) {
    final unidad = unidadAntigua(producto);
    if (unidad.isEmpty || producto.fraccionesSeleccionadas.isEmpty) {
      return unidad;
    }
    return '$unidad · fracción: ${producto.fraccionesSeleccionadas.first}';
  }

  static String _precioMedida(Producto producto, int centavos, String precio) {
    final familia = producto.medidaFamilia;
    final referencia = producto.cantidadReferenciaBase;
    if (familia == null || referencia <= 0) return precio;

    final grande = CantidadesTipicas.unidadGrande(familia);
    final factor = grande.factorBase;
    // Por 1 kg (o 1 L, 1 m, 1 m²) se dice "/ kg", sin repetir el 1.
    if (referencia == factor) return '$precio / ${grande.nombre}';

    final texto =
        '$precio / ${CantidadesTipicas.etiqueta(familia, referencia)}';
    final porGrande = centavos * factor;
    if (porGrande % referencia != 0) return texto;
    return '$texto · S/ ${centavosATexto(porGrande ~/ referencia)} / '
        '${grande.nombre}';
  }

  /// El nombre de la presentación: el guardado en el producto (cubre las
  /// propias del negocio, como «Jaba») o, en productos anteriores, el del
  /// catálogo global.
  static String? _nombrePresentacion(Producto producto) {
    if (producto.presentacionNombre.isNotEmpty) {
      return producto.presentacionNombre;
    }
    return CatalogoVentaGlobal.nombres[producto.presentacionId];
  }

  static String _sufijoPresentacion(Producto producto) {
    final nombre = _nombrePresentacion(producto);
    if (nombre == null) return '';
    final base = nombre.toLowerCase();
    final familia = producto.formatoFamilia;
    if (familia == null || producto.formatoValorBase <= 0) return base;
    if (familia == FamiliaUnidad.conteo && producto.formatoValorBase == 1) {
      return base;
    }
    final formato = LecturaUnidadesProducto.etiquetaDeFormato(
      valorBase: producto.formatoValorBase,
      familiaNombre: familia.name,
      unidadNombre: producto.formatoUnidad,
    );
    return formato.isEmpty ? base : '$base ($formato)';
  }
}
