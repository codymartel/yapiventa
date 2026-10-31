// ═════════════════════════════════════════════════════════════════════════
// Producto
// ═════════════════════════════════════════════════════════════════════════
// fec/2026: agregado fechaVencimiento (DateTime?, opcional). Si es null,
// el producto no tiene caducidad y no se muestra gestión de vencimiento.
// Migración de tu `data class Producto`. Dos campos agregados respecto
// al Kotlin original, por decisiones tomadas en esta sesión:
//   - negocioId: hoy vale lo mismo que el uid del dueño, pero deja la
//     puerta abierta a colaboradores/roles compartiendo un negocio sin
//     tener que migrar datos después.
//   - cloudinaryPublicId: no se usa todavía (Cloudinary aún no está
//     conectado), pero se guarda desde ya para poder borrar imágenes
//     de Cloudinary en el futuro sin tener que rastrear fotos viejas
//     sin ID.
//
// oct/2026: modo de venta (ModoVenta). El producto deja de ser "un precio
// y una unidad suelta" y pasa a declarar CÓMO se vende:
//   - ModoVenta.presentacion: se cuentan presentaciones enteras. El tamaño
//     físico (botella de 625 ml) es información del producto, no stock.
//   - ModoVenta.medida: se vende por una familia medible (peso, volumen,
//     longitud, área) contra una cantidad de referencia y su precio. El
//     stock real vive en la UNIDAD BASE (gramos, mililitros...), entero.
//
// REGLA DE ESCRITURA (una sola boca): los campos de la "vista legacy"
// (precio, stock, unidadMedidaNombre, fraccionesSeleccionadas) los DERIVA
// ProductoFirestoreMapper desde este modelo. Ninguna otra capa los fija:
// existen porque la web pública y el formulario viejo todavía los leen.
// ═════════════════════════════════════════════════════════════════════════

import 'estructura_producto.dart';
import 'familia_unidad.dart';
import 'modo_venta.dart';

class Producto {
  final String id;
  final String negocioId;
  final String nombre;

  // ── Vista legacy (los escribe SOLO ProductoFirestoreMapper) ──────────
  final double precio;
  final int stock;
  final String unidadMedidaNombre;
  final List<String> fraccionesSeleccionadas;

  // ── Modo de venta ────────────────────────────────────────────────────
  final ModoVenta modoVenta;

  /// ModoVenta.presentacion: id estable de la presentación elegida
  /// ('unidad', 'botella', 'frasco'...). Vacío en productos legacy leídos
  /// cuyo nombre no coincide con ninguna del catálogo global.
  final String presentacionId;

  /// Nombre de la presentación tal como se llamaba al guardar ("Jaba", "Botella").
  /// Se guarda aparte porque las presentaciones propias del negocio no están en
  /// el catálogo global: sin esto la tarjeta no podría decir «12 jabas».
  final String presentacionNombre;

  /// Tamaño físico de la presentación, en la unidad BASE de su familia
  /// (625 ml → 625, familia volumen). 0 cuando no aplica o no se conoce.
  final int formatoValorBase;
  final FamiliaUnidad? formatoFamilia;
  final String formatoUnidad;

  /// ModoVenta.medida: familia medible y su unidad visual (kg, L...),
  /// congeladas al crear el producto para que la etiqueta legacy y el
  /// precio por unidad visual sigan siendo coherentes aunque el negocio
  /// cambie después la unidad visual del catálogo.
  final FamiliaUnidad? medidaFamilia;
  final String medidaUnidad;

  /// Precio, en CÉNTIMOS, de la unidad de venta del modo:
  ///   - presentacion → precio de UNA presentación.
  ///   - medida       → precio de [cantidadReferenciaBase].
  final int precioCentavos;

  /// Cantidad (en unidad base de [medidaFamilia]) que cubre
  /// [precioCentavos] en modo medida. 0 en modo presentación.
  final int cantidadReferenciaBase;

  /// Stock real en unidad base (gramos, mililitros, mm, cm²) en modo
  /// medida. null en modo presentación y en productos legacy leídos.
  final int? stockBase;

  /// Mínimo e incremento PROPIOS del producto en modo medida, en unidad base
  /// (ej. jamonada desde 100 g, de 50 en 50 g). null = usa la regla de la
  /// medida del negocio.
  final int? minimoBase;
  final int? incrementoBase;

  /// Etiqueta de unidad heredada, de uso exclusivo para productos legacy
  /// leídos cuyo nombre NO coincide con una presentación del catálogo
  /// (ej. "kg"). Sin ella, reescribir el producto perdería la etiqueta.
  final String etiquetaUnidad;

  /// Variables del producto (paso 3). [modelos] vacío = producto simple, como
  /// siempre. Con modelos, [tituloModelos] es la palabra del vendedor ("Color",
  /// "Aroma") y [tituloFilas] la de sus filas ("Talla", "Formato"); el stock
  /// vive en las filas y [precioCentavos] / [stock] / [stockBase] guardan los
  /// totales DERIVADOS (precio "desde" y suma) para quien aún los lee.
  final String tituloModelos;
  final String tituloFilas;
  final List<ModeloProducto> modelos;

  /// Lo que el cliente puede agregar (extras): sin stock, con precio opcional.
  /// Solo en productos que se cuentan; un producto por medida no los tiene.
  final List<ExtraProducto> extras;

  final bool esStockInfinito;
  final String descripcion;
  final String categoria;
  final bool disponible;
  final bool tieneDelivery;
  final String urlImagen;
  final String? cloudinaryPublicId;
  final DateTime? fechaVencimiento;

  Producto({
    this.id = '',
    required this.negocioId,
    required this.nombre,
    this.precio = 0.0,
    this.stock = 0,
    this.esStockInfinito = false,
    this.descripcion = '',
    this.categoria = '',
    this.disponible = true,
    this.tieneDelivery = false,
    this.urlImagen = '',
    this.cloudinaryPublicId,
    this.unidadMedidaNombre = '',
    this.fraccionesSeleccionadas = const [],
    this.fechaVencimiento,
    this.modoVenta = ModoVenta.presentacion,
    this.presentacionId = '',
    this.presentacionNombre = '',
    this.formatoValorBase = 0,
    this.formatoFamilia,
    this.formatoUnidad = '',
    this.medidaFamilia,
    this.medidaUnidad = '',
    this.precioCentavos = 0,
    this.cantidadReferenciaBase = 0,
    this.stockBase,
    this.minimoBase,
    this.incrementoBase,
    this.etiquetaUnidad = '',
    this.tituloModelos = '',
    this.tituloFilas = '',
    this.modelos = const [],
    this.extras = const [],
  });

  /// true si el producto tiene modelos (variables).
  bool get tieneModelos => modelos.isNotEmpty;

  /// true si el producto se vende por medida (peso, volumen, longitud, área).
  bool get esPorMedida => modoVenta == ModoVenta.medida;

  Producto copyWith({
    String? id,
    String? negocioId,
    String? nombre,
    double? precio,
    int? stock,
    bool? esStockInfinito,
    String? descripcion,
    String? categoria,
    bool? disponible,
    bool? tieneDelivery,
    String? urlImagen,
    String? cloudinaryPublicId,
    String? unidadMedidaNombre,
    List<String>? fraccionesSeleccionadas,
    DateTime? fechaVencimiento,
    ModoVenta? modoVenta,
    String? presentacionId,
    String? presentacionNombre,
    int? formatoValorBase,
    FamiliaUnidad? formatoFamilia,
    String? formatoUnidad,
    FamiliaUnidad? medidaFamilia,
    String? medidaUnidad,
    int? precioCentavos,
    int? cantidadReferenciaBase,
    int? stockBase,
    int? minimoBase,
    int? incrementoBase,
    String? etiquetaUnidad,
    String? tituloModelos,
    String? tituloFilas,
    List<ModeloProducto>? modelos,
    List<ExtraProducto>? extras,
  }) {
    return Producto(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      esStockInfinito: esStockInfinito ?? this.esStockInfinito,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      disponible: disponible ?? this.disponible,
      tieneDelivery: tieneDelivery ?? this.tieneDelivery,
      urlImagen: urlImagen ?? this.urlImagen,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      unidadMedidaNombre: unidadMedidaNombre ?? this.unidadMedidaNombre,
      fraccionesSeleccionadas:
          fraccionesSeleccionadas ?? this.fraccionesSeleccionadas,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      modoVenta: modoVenta ?? this.modoVenta,
      presentacionId: presentacionId ?? this.presentacionId,
      presentacionNombre: presentacionNombre ?? this.presentacionNombre,
      formatoValorBase: formatoValorBase ?? this.formatoValorBase,
      formatoFamilia: formatoFamilia ?? this.formatoFamilia,
      formatoUnidad: formatoUnidad ?? this.formatoUnidad,
      medidaFamilia: medidaFamilia ?? this.medidaFamilia,
      medidaUnidad: medidaUnidad ?? this.medidaUnidad,
      precioCentavos: precioCentavos ?? this.precioCentavos,
      cantidadReferenciaBase:
          cantidadReferenciaBase ?? this.cantidadReferenciaBase,
      stockBase: stockBase ?? this.stockBase,
      minimoBase: minimoBase ?? this.minimoBase,
      incrementoBase: incrementoBase ?? this.incrementoBase,
      etiquetaUnidad: etiquetaUnidad ?? this.etiquetaUnidad,
      tituloModelos: tituloModelos ?? this.tituloModelos,
      tituloFilas: tituloFilas ?? this.tituloFilas,
      modelos: modelos ?? this.modelos,
      extras: extras ?? this.extras,
    );
  }
}
