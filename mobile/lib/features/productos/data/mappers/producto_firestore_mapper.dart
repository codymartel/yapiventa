import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/modo_venta.dart';
import '../../domain/models/producto.dart';
import 'estructura_producto_mapper.dart';
import 'lectura_firestore.dart';
import 'vista_legacy_producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// ProductoFirestoreMapper
// ═════════════════════════════════════════════════════════════════════════
// Traduce entre Firestore y [Producto]. Es la ÚNICA boca que escribe los
// campos de la vista legacy (precio, stock, unidadMedidaNombre,
// fraccionesSeleccionadas): siempre se DERIVAN del modelo de venta
// (VistaLegacyProducto), nunca al revés. Existen porque la web pública y el
// formulario viejo los leen.
//
// LECTURA DE DOCUMENTOS VIEJOS (sin 'modoVenta'): se abren como
// ModoVenta.presentacion. Si el nombre legacy coincide con una presentación
// del catálogo global se resuelve su presentacionId; si no ("kg"), se
// conserva como etiquetaUnidad para no perderlo al reescribir. Nunca se
// inventa el tamaño físico: formatoValorBase queda en 0.
//
// MODELOS (variables): viajan embebidos en el mismo documento
// (EstructuraProductoMapper). Con modelos, precioCentavos / stock / stockBase
// del producto son los totales DERIVADOS que arma ConstructorProducto, así
// que la vista legacy (VistaLegacyProducto) sigue funcionando sin cambios.
// ═════════════════════════════════════════════════════════════════════════

abstract final class ProductoFirestoreMapper {
  static Producto? desdeFirestore(String id, Map<String, dynamic>? data) {
    final nombre = data?['nombre'] as String?;
    final negocioId = data?['negocioId'] as String?;
    if (data == null || nombre == null || negocioId == null) return null;

    final modo = LecturaFirestore.modoDesde(data['modoVenta']);
    if (modo == ModoVenta.medida) {
      return _productoMedida(id, negocioId, nombre, data);
    }
    return _productoPresentacion(id, negocioId, nombre, data);
  }

  static Producto _productoMedida(
    String id,
    String negocioId,
    String nombre,
    Map<String, dynamic> data,
  ) {
    final familia = LecturaFirestore.familiaDesde(data['medidaFamilia']);
    final unidad = LecturaFirestore.texto(data['medidaUnidad']);
    final referencia = LecturaFirestore.entero(data['cantidadReferenciaBase']);
    final centavos = LecturaFirestore.entero(data['precioCentavos']);
    final stockBaseLeido = data['stockBase'] is int
        ? data['stockBase'] as int
        : null;
    final factor = VistaLegacyProducto.factorBase(unidad);

    return Producto(
      id: id,
      negocioId: negocioId,
      nombre: nombre,
      modoVenta: ModoVenta.medida,
      medidaFamilia: familia,
      medidaUnidad: unidad,
      cantidadReferenciaBase: referencia,
      precioCentavos: centavos,
      stockBase: stockBaseLeido,
      minimoBase: LecturaFirestore.enteroPositivoOpcional(data['minimoBase']),
      incrementoBase: LecturaFirestore.enteroPositivoOpcional(
        data['incrementoBase'],
      ),
      precio: VistaLegacyProducto.centavosASoles(
        VistaLegacyProducto.precioPorUnidadVisual(centavos, referencia, factor),
      ),
      stock: stockBaseLeido == null || factor <= 0
          ? LecturaFirestore.entero(data['stock'])
          : stockBaseLeido ~/ factor,
      esStockInfinito: data['esStockInfinito'] as bool? ?? false,
      descripcion: data['descripcion'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      disponible: data['disponible'] as bool? ?? true,
      tieneDelivery: data['tieneDelivery'] as bool? ?? false,
      urlImagen: data['urlImagen'] as String? ?? '',
      cloudinaryPublicId: data['cloudinaryPublicId'] as String?,
      unidadMedidaNombre: unidad,
      fraccionesSeleccionadas: const [],
      fechaVencimiento: (data['fechaVencimiento'] as Timestamp?)?.toDate(),
      tituloModelos: LecturaFirestore.texto(data['tituloModelos']),
      tituloFilas: LecturaFirestore.texto(data['tituloFilas']),
      modelos: EstructuraProductoMapper.modelosDesde(data['modelos']),
      extras: EstructuraProductoMapper.extrasDesde(data['extras']),
    );
  }

  static Producto _productoPresentacion(
    String id,
    String negocioId,
    String nombre,
    Map<String, dynamic> data,
  ) {
    final presentacionIdGuardada = LecturaFirestore.texto(
      data['presentacionId'],
    );
    final nombreLegacy = LecturaFirestore.texto(data['unidadMedidaNombre']);
    // Documento viejo sin presentacionId: se intenta resolver la
    // presentación por su nombre legacy. Si no coincide con ninguna del
    // catálogo global ("kg"), queda en '' y la etiqueta sobrevive en
    // etiquetaUnidad.
    final presentacionIdResuelta = presentacionIdGuardada.isNotEmpty
        ? presentacionIdGuardada
        : VistaLegacyProducto.presentacionIdDeNombre(nombreLegacy) ?? '';
    final etiquetaLegacy = nombreLegacy.isNotEmpty
        ? nombreLegacy
        : LecturaFirestore.texto(data['etiquetaUnidad']);

    return Producto(
      id: id,
      negocioId: negocioId,
      nombre: nombre,
      modoVenta: ModoVenta.presentacion,
      presentacionId: presentacionIdResuelta,
      presentacionNombre: LecturaFirestore.texto(data['presentacionNombre']),
      formatoValorBase: LecturaFirestore.entero(data['formatoValorBase']),
      formatoFamilia: LecturaFirestore.familiaDesde(data['formatoFamilia']),
      formatoUnidad: LecturaFirestore.texto(data['formatoUnidad']),
      precioCentavos: VistaLegacyProducto.solesACentavos(data['precio']),
      etiquetaUnidad: presentacionIdResuelta.isEmpty ? etiquetaLegacy : '',
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      esStockInfinito: data['esStockInfinito'] as bool? ?? false,
      descripcion: data['descripcion'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      disponible: data['disponible'] as bool? ?? true,
      tieneDelivery: data['tieneDelivery'] as bool? ?? false,
      urlImagen: data['urlImagen'] as String? ?? '',
      cloudinaryPublicId: data['cloudinaryPublicId'] as String?,
      unidadMedidaNombre: nombreLegacy,
      fraccionesSeleccionadas:
          (data['fraccionesSeleccionadas'] as List?)?.cast<String>() ?? [],
      fechaVencimiento: (data['fechaVencimiento'] as Timestamp?)?.toDate(),
      tituloModelos: LecturaFirestore.texto(data['tituloModelos']),
      tituloFilas: LecturaFirestore.texto(data['tituloFilas']),
      modelos: EstructuraProductoMapper.modelosDesde(data['modelos']),
      extras: EstructuraProductoMapper.extrasDesde(data['extras']),
    );
  }

  static Map<String, dynamic> paraFirestore(Producto producto) {
    return {
      'negocioId': producto.negocioId,
      'nombre': producto.nombre,
      'precio': VistaLegacyProducto.precio(producto),
      'stock': VistaLegacyProducto.stock(producto),
      'esStockInfinito': producto.esStockInfinito,
      'descripcion': producto.descripcion,
      'categoria': producto.categoria,
      'disponible': producto.disponible,
      'tieneDelivery': producto.tieneDelivery,
      'urlImagen': producto.urlImagen,
      'cloudinaryPublicId': producto.cloudinaryPublicId,
      'unidadMedidaNombre': VistaLegacyProducto.unidad(producto),
      'fraccionesSeleccionadas': VistaLegacyProducto.fracciones(producto),
      'fechaVencimiento': producto.fechaVencimiento == null
          ? null
          : Timestamp.fromDate(producto.fechaVencimiento!),
      'modoVenta': producto.modoVenta.name,
      'presentacionId': producto.presentacionId,
      'presentacionNombre': producto.presentacionNombre,
      'formatoValorBase': producto.formatoValorBase,
      'formatoFamilia': producto.formatoFamilia?.name,
      'formatoUnidad': producto.formatoUnidad,
      'etiquetaUnidad': producto.etiquetaUnidad,
      'medidaFamilia': producto.medidaFamilia?.name,
      'medidaUnidad': producto.medidaUnidad,
      'precioCentavos': producto.precioCentavos,
      'cantidadReferenciaBase': producto.cantidadReferenciaBase,
      'stockBase': producto.stockBase,
      'minimoBase': producto.minimoBase,
      'incrementoBase': producto.incrementoBase,
      'tituloModelos': producto.tituloModelos,
      'tituloFilas': producto.tituloFilas,
      'modelos': EstructuraProductoMapper.modelosAMapas(producto.modelos),
      'extras': EstructuraProductoMapper.extrasAMapas(producto.extras),
    };
  }
}
