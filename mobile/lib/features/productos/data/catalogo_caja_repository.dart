import 'package:cloud_firestore/cloud_firestore.dart';

import '../application/services/campos_catalogo_producto.dart';
import '../domain/models/consulta_catalogo_caja.dart';
import '../domain/models/pagina_productos.dart';
import '../domain/models/producto.dart';
import '../domain/repositories/repositorio_catalogo_caja.dart';
import 'mappers/producto_firestore_mapper.dart';

class _CursorCatalogoFirestore implements CursorProductos {
  const _CursorCatalogoFirestore(this.documento);

  final DocumentSnapshot<Map<String, dynamic>> documento;
}

/// El catálogo de Caja bajo `negocios/{id}/productos`, de 20 en 20.
///
/// Solo trae productos con `disponible == true`. Según la consulta:
///   - con texto (2 letras o más): por el INICIO del nombre
///     (`nombreBusqueda`), ordenado por nombre;
///   - sin texto: Frecuentes (`vendidos` y luego los más recientes),
///     Recientes (`fechaCreacion`) o Nombre (`nombreBusqueda`).
/// El tipo (`tipoCaja`) y la categoría filtran por igualdad.
///
/// Un producto SIN `nombreBusqueda` no sale en Nombre ni en la búsqueda, y uno
/// sin `vendidos` no sale en Frecuentes (Firestore deja fuera los documentos
/// que no tienen el campo por el que se ordena). Por eso los productos viejos
/// necesitan el relleno único; Recientes los muestra a todos.
///
/// Necesita los índices compuestos de `firestore.indexes.json`.
class CatalogoCajaRepository implements RepositorioCatalogoCaja {
  CatalogoCajaRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Marca de fin para la búsqueda por prefijo (un carácter muy alto).
  static const String _finPrefijo = '';

  @override
  Future<PaginaProductos> obtenerPagina(
    String negocioId,
    ConsultaCatalogoCaja consulta, {
    CursorProductos? despuesDe,
    int limite = 20,
  }) async {
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No se encontró un negocioId para leer el catálogo.');
    }
    if (limite < 1 || limite > 50) {
      throw ArgumentError.value(limite, 'limite', 'Entre 1 y 50.');
    }

    var query = _db
        .collection('negocios')
        .doc(id)
        .collection('productos')
        .where('disponible', isEqualTo: true);

    final tipo = consulta.tipo;
    if (tipo != null && tipo.isNotEmpty) {
      query = query.where('tipoCaja', isEqualTo: tipo);
    }
    final categoria = consulta.categoria;
    if (categoria != null && categoria.isNotEmpty) {
      query = query.where('categoria', isEqualTo: categoria);
    }

    final texto = CamposCatalogoProducto.nombreBusqueda(consulta.texto);
    if (texto.length >= CamposCatalogoProducto.minimoLetras) {
      query = query
          .where('nombreBusqueda', isGreaterThanOrEqualTo: texto)
          .where('nombreBusqueda', isLessThan: '$texto$_finPrefijo')
          .orderBy('nombreBusqueda');
    } else {
      query = switch (consulta.orden) {
        OrdenCatalogoCaja.frecuentes =>
          query
              .orderBy('vendidos', descending: true)
              .orderBy('fechaCreacion', descending: true),
        OrdenCatalogoCaja.recientes => query.orderBy(
          'fechaCreacion',
          descending: true,
        ),
        OrdenCatalogoCaja.nombre => query.orderBy('nombreBusqueda'),
      };
    }

    if (despuesDe != null) {
      if (despuesDe is! _CursorCatalogoFirestore) {
        throw ArgumentError.value(
          despuesDe,
          'despuesDe',
          'El cursor no pertenece a CatalogoCajaRepository.',
        );
      }
      query = query.startAfterDocument(despuesDe.documento);
    }

    // Un documento de más solo para saber si existe otra página.
    final resultado = await query.limit(limite + 1).get();
    final pagina = resultado.docs.take(limite).toList();
    return PaginaProductos(
      productos: pagina
          .map((d) => ProductoFirestoreMapper.desdeFirestore(d.id, d.data()))
          .whereType<Producto>()
          .toList(),
      ultimoCursor: pagina.isEmpty
          ? null
          : _CursorCatalogoFirestore(pagina.last),
      hayMas: resultado.docs.length > limite,
    );
  }
}
