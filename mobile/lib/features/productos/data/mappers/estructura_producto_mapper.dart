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
