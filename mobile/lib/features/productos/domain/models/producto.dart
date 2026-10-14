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

  /// Etiqueta de unidad heredada, de uso exclusivo para productos legacy
  /// leídos cuyo nombre NO coincide con una presentación del catálogo
  /// (ej. "kg"). Sin ella, reescribir el producto perdería la etiqueta.
  final String etiquetaUnidad;

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
    this.formatoValorBase = 0,
    this.formatoFamilia,
    this.formatoUnidad = '',
    this.medidaFamilia,
    this.medidaUnidad = '',
    this.precioCentavos = 0,
    this.cantidadReferenciaBase = 0,
    this.stockBase,
    this.etiquetaUnidad = '',
  });

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
    int? formatoValorBase,
    FamiliaUnidad? formatoFamilia,
    String? formatoUnidad,
    FamiliaUnidad? medidaFamilia,
    String? medidaUnidad,
    int? precioCentavos,
    int? cantidadReferenciaBase,
    int? stockBase,
    String? etiquetaUnidad,
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
      formatoValorBase: formatoValorBase ?? this.formatoValorBase,
      formatoFamilia: formatoFamilia ?? this.formatoFamilia,
      formatoUnidad: formatoUnidad ?? this.formatoUnidad,
      medidaFamilia: medidaFamilia ?? this.medidaFamilia,
      medidaUnidad: medidaUnidad ?? this.medidaUnidad,
      precioCentavos: precioCentavos ?? this.precioCentavos,
      cantidadReferenciaBase:
          cantidadReferenciaBase ?? this.cantidadReferenciaBase,
      stockBase: stockBase ?? this.stockBase,
      etiquetaUnidad: etiquetaUnidad ?? this.etiquetaUnidad,
    );
  }
}
