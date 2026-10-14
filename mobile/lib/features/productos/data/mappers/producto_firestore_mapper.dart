import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_global.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';

import '../../domain/models/familia_unidad.dart';
import '../../domain/models/modo_venta.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// ProductoFirestoreMapper
// ═════════════════════════════════════════════════════════════════════════
// Traduce entre Firestore y [Producto]. Es la ÚNICA boca que escribe los
// campos de la vista legacy (precio, stock, unidadMedidaNombre,
// fraccionesSeleccionadas): siempre se DERIVAN del modelo de venta, nunca
// al revés. Existen porque la web pública y el formulario viejo los leen.
//
// DERIVACIÓN HACIA LEGACY (paraFirestore):
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
// LECTURA DE DOCUMENTOS VIEJOS (sin 'modoVenta'): se abren como
// ModoVenta.presentacion. Si el nombre legacy coincide con una presentación
// del catálogo global se resuelve su presentacionId; si no ("kg"), se
// conserva como etiquetaUnidad para no perderlo al reescribir. Nunca se
// inventa el tamaño físico: formatoValorBase queda en 0.
//
// Las importaciones del registro cerrado (catálogo global, unidades) son
// PURAS: sin Firestore, sin providers. Hacen falta para derivar nombres y
// etiquetas, no para leer datos.
// ═════════════════════════════════════════════════════════════════════════

abstract final class ProductoFirestoreMapper {
  static Producto? desdeFirestore(String id, Map<String, dynamic>? data) {
    final nombre = data?['nombre'] as String?;
    final negocioId = data?['negocioId'] as String?;
    if (data == null || nombre == null || negocioId == null) return null;

    final modo = _modoDesde(data['modoVenta']);
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
    final familia = _familiaDesde(data['medidaFamilia']);
    final unidad = _texto(data['medidaUnidad']);
    final referencia = _entero(data['cantidadReferenciaBase']);
    final centavos = _entero(data['precioCentavos']);
    final stockBaseLeido = data['stockBase'] is int ? data['stockBase'] as int : null;
    final factor = _factorBase(unidad);

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
      precio: _centavosASoles(
        _precioPorUnidadVisual(centavos, referencia, factor),
      ),
      stock: stockBaseLeido == null || factor <= 0
          ? _entero(data['stock'])
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
    );
  }

  static Producto _productoPresentacion(
    String id,
    String negocioId,
    String nombre,
    Map<String, dynamic> data,
  ) {
    final presentacionIdGuardada = _texto(data['presentacionId']);
    final nombreLegacy = _texto(data['unidadMedidaNombre']);
    // Documento viejo sin presentacionId: se intenta resolver la
    // presentación por su nombre legacy. Si no coincide con ninguna del
    // catálogo global ("kg"), queda en '' y la etiqueta sobrevive en
    // etiquetaUnidad.
    final presentacionIdResuelta = presentacionIdGuardada.isNotEmpty
        ? presentacionIdGuardada
        : _presentacionIdDeNombre(nombreLegacy) ?? '';
    final etiquetaLegacy = nombreLegacy.isNotEmpty
        ? nombreLegacy
        : _texto(data['etiquetaUnidad']);

    return Producto(
      id: id,
      negocioId: negocioId,
      nombre: nombre,
      modoVenta: ModoVenta.presentacion,
      presentacionId: presentacionIdResuelta,
      formatoValorBase: _entero(data['formatoValorBase']),
      formatoFamilia: _familiaDesde(data['formatoFamilia']),
      formatoUnidad: _texto(data['formatoUnidad']),
      precioCentavos: _solesACentavos(data['precio']),
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
    );
  }

  static Map<String, dynamic> paraFirestore(Producto producto) {
    return {
      'negocioId': producto.negocioId,
      'nombre': producto.nombre,
      'precio': _precioLegacy(producto),
      'stock': _stockLegacy(producto),
      'esStockInfinito': producto.esStockInfinito,
      'descripcion': producto.descripcion,
      'categoria': producto.categoria,
      'disponible': producto.disponible,
      'tieneDelivery': producto.tieneDelivery,
      'urlImagen': producto.urlImagen,
      'cloudinaryPublicId': producto.cloudinaryPublicId,
      'unidadMedidaNombre': _unidadLegacy(producto),
      'fraccionesSeleccionadas': _fraccionesLegacy(producto),
      'fechaVencimiento': producto.fechaVencimiento == null
          ? null
          : Timestamp.fromDate(producto.fechaVencimiento!),
      'modoVenta': producto.modoVenta.name,
      'presentacionId': producto.presentacionId,
      'formatoValorBase': producto.formatoValorBase,
      'formatoFamilia': producto.formatoFamilia?.name,
      'formatoUnidad': producto.formatoUnidad,
      'etiquetaUnidad': producto.etiquetaUnidad,
      'medidaFamilia': producto.medidaFamilia?.name,
      'medidaUnidad': producto.medidaUnidad,
      'precioCentavos': producto.precioCentavos,
      'cantidadReferenciaBase': producto.cantidadReferenciaBase,
      'stockBase': producto.stockBase,
    };
  }

  // ── Derivaciones a la vista legacy ────────────────────────────────────

  static double _precioLegacy(Producto producto) {
    if (!producto.esPorMedida) {
      return _centavosASoles(producto.precioCentavos);
    }
    final precio = _precioPorUnidadVisual(
      producto.precioCentavos,
      producto.cantidadReferenciaBase,
      _factorBase(producto.medidaUnidad),
    );
    return _centavosASoles(precio);
  }

  static int _stockLegacy(Producto producto) {
    if (!producto.esPorMedida) return producto.stock;
    final stockBase = producto.stockBase;
    if (stockBase == null) return producto.stock;
    final factor = _factorBase(producto.medidaUnidad);
    if (factor <= 0) return producto.stock;
    // Piso: la web vende unidades visuales enteras; nunca se promete más
    // stock del que realmente hay.
    return stockBase ~/ factor;
  }

  static String _unidadLegacy(Producto producto) {
    if (!producto.esPorMedida) {
      if (producto.presentacionId.isNotEmpty) {
        final nombre = _nombrePresentacion(producto.presentacionId);
        if (nombre != null) return nombre;
      }
      return producto.etiquetaUnidad;
    }
    return producto.medidaUnidad;
  }

  static List<String> _fraccionesLegacy(Producto producto) {
    if (producto.esPorMedida) return const [];
    final etiqueta = _etiquetaFormato(
      producto.formatoValorBase,
      producto.formatoFamilia,
      producto.formatoUnidad,
    );
    if (etiqueta != null) return [etiqueta];
    // Sin formato conocido (productos legacy leídos): se conserva la lista.
    return producto.fraccionesSeleccionadas;
  }

  // ── Aritmética entera ─────────────────────────────────────────────────

  /// Precio por UNA unidad visual, en céntimos, con piso. Si la referencia
  /// no es un múltiplo exacto de la unidad visual, el piso garantiza que
  /// nunca se cobre más de lo correcto por unidad.
  static int _precioPorUnidadVisual(
    int centavos,
    int referenciaBase,
    int factorBase,
  ) {
    if (referenciaBase <= 0) return centavos;
    if (factorBase <= 0) return centavos;
    return (centavos * factorBase) ~/ referenciaBase;
  }

  static double _centavosASoles(int centavos) => centavos / 100;

  static int _solesACentavos(Object? precio) {
    final soles = (precio as num?)?.toDouble() ?? 0;
    return (soles * 100).round();
  }

  // ── Registro cerrado (puro, sin I/O) ──────────────────────────────────

  static int _factorBase(String nombreUnidad) {
    final unidad = _unidadRegistrada(nombreUnidad);
    return unidad?.factorBase ?? 0;
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

  /// Presentación del catálogo global cuyo nombre coincide (sin distinguir
  /// mayúsculas) con la etiqueta legacy. null si no coincide con ninguna.
  static String? _presentacionIdDeNombre(String nombre) {
    if (nombre.isEmpty) return null;
    for (final entrada in CatalogoVentaGlobal.nombres.entries) {
      if (entrada.value.toLowerCase() == nombre.toLowerCase()) {
        return entrada.key;
      }
    }
    return null;
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

  // ── Lecturas defensivas de Firestore ──────────────────────────────────

  static ModoVenta _modoDesde(Object? valor) {
    if (valor is String && valor == ModoVenta.medida.name) {
      return ModoVenta.medida;
    }
    return ModoVenta.presentacion;
  }

  static FamiliaUnidad? _familiaDesde(Object? valor) {
    if (valor is! String) return null;
    for (final familia in FamiliaUnidad.values) {
      if (familia.name == valor) return familia;
    }
    return null;
  }

  static int _entero(Object? valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return 0;
  }

  static String _texto(Object? valor) {
    final texto = valor;
    return texto is String ? texto.trim() : '';
  }
}
