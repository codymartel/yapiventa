import 'familia_unidad.dart';

// ═════════════════════════════════════════════════════════════════════════
// FilaVenta + ModeloProducto + ExtraProducto
// ═════════════════════════════════════════════════════════════════════════
// La estructura de un producto con variables (paso 3 del plano):
//
//   Producto  →  modelos (lo que cambia la FOTO: color, aroma, sabor…)
//                  └─ filas "Se vende en" (talla, número, formato…)
//
// El stock vive SIEMPRE en la fila: el modelo no tiene stock propio, su total
// se calcula (TotalesProducto). Todo va dentro del mismo documento del
// producto: sin subcolecciones, sin lecturas extra.
//
// En un producto por presentación cada modelo tiene sus filas. En uno por
// medida (queso fresco / andino) cada modelo tiene UNA fila: su precio (por la
// cantidad de referencia del producto) y su stock en unidad base.
// ═════════════════════════════════════════════════════════════════════════

class FilaVenta {
  const FilaVenta({
    required this.id,
    this.etiqueta = '',
    this.precioCentavos = 0,
    this.stock = 0,
    this.stockBase,
    this.formatoValorBase = 0,
    this.formatoFamilia,
    this.formatoUnidad = '',
  });

  /// Id estable (el pedido lo guardará: producto · modelo · fila).
  final String id;

  /// "S", "M", "38", "500 ml". Vacío en un producto por medida.
  final String etiqueta;
  final int precioCentavos;

  /// Presentación: unidades enteras. Medida: no se usa (ver [stockBase]).
  final int stock;

  /// Medida: stock en unidad base (g, ml…). null en presentación.
  final int? stockBase;

  /// Tamaño real cuando la presentación tiene formatos (botella de 500 ml);
  /// 0 cuando la fila es solo una etiqueta (talla M).
  final int formatoValorBase;
  final FamiliaUnidad? formatoFamilia;
  final String formatoUnidad;

  FilaVenta copyWith({
    String? etiqueta,
    int? precioCentavos,
    int? stock,
    int? stockBase,
  }) {
    return FilaVenta(
      id: id,
      etiqueta: etiqueta ?? this.etiqueta,
      precioCentavos: precioCentavos ?? this.precioCentavos,
      stock: stock ?? this.stock,
      stockBase: stockBase ?? this.stockBase,
      formatoValorBase: formatoValorBase,
      formatoFamilia: formatoFamilia,
      formatoUnidad: formatoUnidad,
    );
  }
}

class ModeloProducto {
  const ModeloProducto({
    required this.id,
    this.nombre = '',
    this.urlImagen = '',
    this.cloudinaryPublicId,
    this.filas = const [],
  });

  final String id;
  final String nombre;
  final String urlImagen;
  final String? cloudinaryPublicId;
  final List<FilaVenta> filas;

  ModeloProducto copyWith({
    String? nombre,
    String? urlImagen,
    String? cloudinaryPublicId,
    List<FilaVenta>? filas,
  }) {
    return ModeloProducto(
      id: id,
      nombre: nombre ?? this.nombre,
      urlImagen: urlImagen ?? this.urlImagen,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      filas: filas ?? this.filas,
    );
  }
}

/// Algo que el cliente puede agregar a un producto («con ají», «+ papas
/// S/ 6»). Es del producto entero, no de cada modelo. NO tiene stock: no se
/// cuenta ni se descuenta. Precio en céntimos enteros; 0 = gratis.
class ExtraProducto {
  const ExtraProducto({
    required this.id,
    required this.nombre,
    this.precioCentavos = 0,
  });

  /// Cuántos extras puede tener un producto.
  static const int maximo = 10;

  final String id;
  final String nombre;
  final int precioCentavos;
}
