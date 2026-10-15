import '../../domain/models/familia_unidad.dart';
import '../../domain/models/modo_venta.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConstructorProducto
// ═════════════════════════════════════════════════════════════════════════
// Arma el Producto a partir de lo ya interpretado en el formulario (números
// en enteros, nunca double). Función pura, sin Flutter.
//
//   - Medida completa       → producto por medida.
//   - Presentación completa → producto por presentación.
//   - Ninguna completa      → se guarda Como Está (legacy sin migrar).
// ═════════════════════════════════════════════════════════════════════════

/// Valores del formulario ya convertidos a enteros del dominio.
class DatosFormularioProducto {
  const DatosFormularioProducto({
    required this.anterior,
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.tieneDelivery,
    required this.urlImagen,
    required this.esStockInfinito,
    required this.modo,
    required this.medidaCompleta,
    this.medidaFamilia,
    this.medidaUnidad = '',
    this.referenciaBase,
    this.precioMedidaCentavos,
    this.stockMedidaBase,
    required this.presentacionCompleta,
    this.presentacionId = '',
    this.formatoValorBase = 0,
    this.formatoFamilia = '',
    this.formatoUnidad = '',
    this.precioPresentacionCentavos,
    this.stockPresentacion = 0,
    this.precioVisibleCentavos,
  });

  /// Producto editado (null si es nuevo).
  final Producto? anterior;
  final String nombre;
  final String descripcion;
  final String categoria;
  final bool tieneDelivery;
  final String urlImagen;
  final bool esStockInfinito;
  final ModoVenta? modo;

  final bool medidaCompleta;
  final FamiliaUnidad? medidaFamilia;
  final String medidaUnidad;
  final int? referenciaBase;
  final int? precioMedidaCentavos;
  final int? stockMedidaBase;

  final bool presentacionCompleta;
  final String presentacionId;
  final int formatoValorBase;
  final String formatoFamilia;
  final String formatoUnidad;
  final int? precioPresentacionCentavos;
  final int stockPresentacion;

  /// Precio escrito en el modo que se ve (para guardar un legacy sin migrar).
  final int? precioVisibleCentavos;
}

class ConstructorProducto {
  ConstructorProducto._();

  static Producto construir(DatosFormularioProducto datos) {
    final anterior = datos.anterior;
    final id = anterior?.id ?? '';
    final negocioId = anterior?.negocioId ?? '';
    final disponible = anterior?.disponible ?? true;

    if (datos.modo == ModoVenta.medida && datos.medidaCompleta) {
      return Producto(
        id: id,
        negocioId: negocioId,
        nombre: datos.nombre,
        descripcion: datos.descripcion,
        categoria: datos.categoria,
        disponible: disponible,
        tieneDelivery: datos.tieneDelivery,
        urlImagen: datos.urlImagen,
        cloudinaryPublicId: anterior?.cloudinaryPublicId,
        fechaVencimiento: anterior?.fechaVencimiento,
        esStockInfinito: datos.esStockInfinito,
        modoVenta: ModoVenta.medida,
        medidaFamilia: datos.medidaFamilia,
        medidaUnidad: datos.medidaUnidad,
        cantidadReferenciaBase: datos.referenciaBase!,
        precioCentavos: datos.precioMedidaCentavos!,
        stockBase: datos.esStockInfinito ? null : datos.stockMedidaBase!,
        stock: anterior?.stock ?? 0,
      );
    }

    if (datos.presentacionCompleta) {
      return Producto(
        id: id,
        negocioId: negocioId,
        nombre: datos.nombre,
        descripcion: datos.descripcion,
        categoria: datos.categoria,
        disponible: disponible,
        tieneDelivery: datos.tieneDelivery,
        urlImagen: datos.urlImagen,
        cloudinaryPublicId: anterior?.cloudinaryPublicId,
        fechaVencimiento: anterior?.fechaVencimiento,
        esStockInfinito: datos.esStockInfinito,
        modoVenta: ModoVenta.presentacion,
        presentacionId: datos.presentacionId,
        formatoValorBase: datos.formatoValorBase,
        formatoFamilia: FamiliaUnidad.values.firstWhere(
          (familia) => familia.name == datos.formatoFamilia,
        ),
        formatoUnidad: datos.formatoUnidad,
        precioCentavos: datos.precioPresentacionCentavos!,
        stock: datos.stockPresentacion,
      );
    }

    // Sin migrar: se conserva la unidad propia y las fracciones leídas.
    return Producto(
      id: id,
      negocioId: negocioId,
      nombre: datos.nombre,
      descripcion: datos.descripcion,
      categoria: datos.categoria,
      disponible: disponible,
      tieneDelivery: datos.tieneDelivery,
      urlImagen: datos.urlImagen,
      cloudinaryPublicId: anterior?.cloudinaryPublicId,
      fechaVencimiento: anterior?.fechaVencimiento,
      esStockInfinito: datos.esStockInfinito,
      modoVenta: ModoVenta.presentacion,
      presentacionId: anterior?.presentacionId ?? '',
      etiquetaUnidad: anterior?.etiquetaUnidad ?? '',
      precioCentavos:
          datos.precioVisibleCentavos ?? anterior?.precioCentavos ?? 0,
      stock: anterior?.stock ?? 0,
      fraccionesSeleccionadas: anterior?.fraccionesSeleccionadas ?? const [],
    );
  }
}
