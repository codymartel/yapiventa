import '../../domain/models/estructura_producto.dart';
import 'lectura_firestore.dart';

// ═════════════════════════════════════════════════════════════════════════
// EstructuraProductoMapper
// ═════════════════════════════════════════════════════════════════════════
// Traduce los modelos y sus filas ("Se vende en") entre el documento del
// producto y el dominio. Todo viaja EMBEBIDO en el documento del producto:
// un producto = una lectura, tenga 1 o 30 modelos.
//
//   modelos: [
//     { id, nombre, urlImagen, cloudinaryPublicId,
//       filas: [ { id, etiqueta, precioCentavos, stock, stockBase?,
//                  formatoValorBase, formatoFamilia, formatoUnidad } ] }
//   ]
//   extras: [ { id, nombre, precioCentavos } ]
//
// La lectura es defensiva: lo que no se entiende se ignora, nunca rompe el
// producto. Sin 'modelos' (producto simple o antiguo) devuelve [].
// ═════════════════════════════════════════════════════════════════════════
abstract final class EstructuraProductoMapper {
  static List<ModeloProducto> modelosDesde(Object? valor) {
    if (valor is! List) return const [];
    final modelos = <ModeloProducto>[];
    for (var i = 0; i < valor.length; i++) {
      final dato = valor[i];
      if (dato is! Map) continue;
      final mapa = Map<String, dynamic>.from(dato);
      final id = LecturaFirestore.texto(mapa['id']);
      modelos.add(
        ModeloProducto(
          id: id.isEmpty ? 'm$i' : id,
          nombre: LecturaFirestore.texto(mapa['nombre']),
          urlImagen: LecturaFirestore.texto(mapa['urlImagen']),
          cloudinaryPublicId: mapa['cloudinaryPublicId'] as String?,
          filas: _filasDesde(mapa['filas']),
        ),
      );
    }
    return modelos;
  }

  static List<FilaVenta> _filasDesde(Object? valor) {
    if (valor is! List) return const [];
    final filas = <FilaVenta>[];
    for (var i = 0; i < valor.length; i++) {
      final dato = valor[i];
      if (dato is! Map) continue;
      final mapa = Map<String, dynamic>.from(dato);
      final id = LecturaFirestore.texto(mapa['id']);
      filas.add(
        FilaVenta(
          id: id.isEmpty ? 'f$i' : id,
          etiqueta: LecturaFirestore.texto(mapa['etiqueta']),
          precioCentavos: LecturaFirestore.entero(mapa['precioCentavos']),
          stock: LecturaFirestore.entero(mapa['stock']),
          stockBase: mapa['stockBase'] is int ? mapa['stockBase'] as int : null,
          formatoValorBase: LecturaFirestore.entero(mapa['formatoValorBase']),
          formatoFamilia: LecturaFirestore.familiaDesde(mapa['formatoFamilia']),
          formatoUnidad: LecturaFirestore.texto(mapa['formatoUnidad']),
        ),
      );
    }
    return filas;
  }

  /// Extras del producto: `extras: [{id, nombre, precioCentavos}]`. Lectura
  /// defensiva: sin nombre se ignora, y nunca pasa del máximo.
  static List<ExtraProducto> extrasDesde(Object? valor) {
    if (valor is! List) return const [];
    final extras = <ExtraProducto>[];
    for (
      var i = 0;
      i < valor.length && extras.length < ExtraProducto.maximo;
      i++
    ) {
      final dato = valor[i];
      if (dato is! Map) continue;
      final mapa = Map<String, dynamic>.from(dato);
      final nombre = LecturaFirestore.texto(mapa['nombre']).trim();
      if (nombre.isEmpty) continue;
      final id = LecturaFirestore.texto(mapa['id']);
      final precio = LecturaFirestore.entero(mapa['precioCentavos']);
      extras.add(
        ExtraProducto(
          id: id.isEmpty ? 'e$i' : id,
          nombre: nombre,
          precioCentavos: precio < 0 ? 0 : precio,
        ),
      );
    }
    return extras;
  }

  /// Partes de un combo: `partes: [{productoId, modeloId, filaId, cantidad,
  /// nombre}]`. Lectura defensiva: sin producto o con cantidad menor que 1 se
  /// ignora, y nunca pasa del máximo.
  static List<ParteCombo> partesDesde(Object? valor) {
    if (valor is! List) return const [];
    final partes = <ParteCombo>[];
    for (final dato in valor) {
      if (partes.length >= ParteCombo.maximo) break;
      if (dato is! Map) continue;
      final mapa = Map<String, dynamic>.from(dato);
      final productoId = LecturaFirestore.texto(mapa['productoId']);
      final cantidad = LecturaFirestore.entero(mapa['cantidad']);
      if (productoId.isEmpty || cantidad < 1) continue;
      partes.add(
        ParteCombo(
          productoId: productoId,
          modeloId: LecturaFirestore.texto(mapa['modeloId']),
          filaId: LecturaFirestore.texto(mapa['filaId']),
          cantidad: cantidad,
          nombre: LecturaFirestore.texto(mapa['nombre']),
          urlImagen: LecturaFirestore.texto(mapa['urlImagen']),
        ),
      );
    }
    return partes;
  }

  static List<Map<String, dynamic>> partesAMapas(List<ParteCombo> partes) {
    return [
      for (final parte in partes)
        {
          'productoId': parte.productoId,
          'modeloId': parte.modeloId,
          'filaId': parte.filaId,
          'cantidad': parte.cantidad,
          'nombre': parte.nombre,
          'urlImagen': parte.urlImagen,
        },
    ];
  }

  /// Los ids de los productos que usa un combo, sin repetir: sirve para saber
  /// qué producto está dentro de algún combo.
  static List<String> idsDeProductos(List<ParteCombo> partes) => [
    ...{for (final parte in partes) parte.productoId},
  ];

  static List<Map<String, dynamic>> extrasAMapas(List<ExtraProducto> extras) {
    return [
      for (final extra in extras)
        {
          'id': extra.id,
          'nombre': extra.nombre,
          'precioCentavos': extra.precioCentavos,
        },
    ];
  }

  static List<Map<String, dynamic>> modelosAMapas(
    List<ModeloProducto> modelos,
  ) {
    return [
      for (final modelo in modelos)
        {
          'id': modelo.id,
          'nombre': modelo.nombre,
          'urlImagen': modelo.urlImagen,
          'cloudinaryPublicId': modelo.cloudinaryPublicId,
          'filas': [
            for (final fila in modelo.filas)
              {
                'id': fila.id,
                'etiqueta': fila.etiqueta,
                'precioCentavos': fila.precioCentavos,
                'stock': fila.stock,
                'stockBase': fila.stockBase,
                'formatoValorBase': fila.formatoValorBase,
                'formatoFamilia': fila.formatoFamilia?.name,
                'formatoUnidad': fila.formatoUnidad,
              },
          ],
        },
    ];
  }
}
