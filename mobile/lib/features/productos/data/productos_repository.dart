import 'package:cloud_firestore/cloud_firestore.dart';
import 'mappers/producto_firestore_mapper.dart';
import '../domain/models/pagina_productos.dart';
import '../domain/models/producto.dart';
import '../domain/repositories/repositorio_productos.dart';

class _CursorProductosFirestore implements CursorProductos {
  final DocumentSnapshot<Map<String, dynamic>> documento;

  const _CursorProductosFirestore(this.documento);
}

class ProductosRepository implements RepositorioProductos {
  final FirebaseFirestore _db;

  ProductosRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _coleccionProductos(String uid) =>
      _db.collection('users').doc(uid).collection('productos');

  // Equivale a pedir una pagina manual del catalogo: la primera consulta
  // trae los 10 productos mas recientes y las siguientes continuan desde
  // [despuesDe], sin volver a leer los documentos de paginas anteriores.
  @override
  Future<PaginaProductos> obtenerPaginaProductos(
    String uid, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) async {
    Query<Map<String, dynamic>> query = _coleccionProductos(
      uid,
    ).orderBy('fechaCreacion', descending: true);

    if (despuesDe != null) {
      if (despuesDe is! _CursorProductosFirestore) {
        throw ArgumentError.value(
          despuesDe,
          'despuesDe',
          'El cursor no pertenece a ProductosRepository.',
        );
      }
      query = query.startAfterDocument(despuesDe.documento);
    }

    // Se pide un documento adicional solo para saber si existe otra página.
    query = query.limit(limite + 1);

    final snapshot = await query.get();
    final documentosPagina = snapshot.docs.take(limite).toList();

    final productos = documentosPagina
        .map((documento) {
          return ProductoFirestoreMapper.desdeFirestore(
            documento.id,
            documento.data(),
          );
        })
        .whereType<Producto>()
        .toList();

    return PaginaProductos(
      productos: productos,
      ultimoCursor: documentosPagina.isNotEmpty
          ? _CursorProductosFirestore(documentosPagina.last)
          : null,
      hayMas: snapshot.docs.length > limite,
    );
  }

  @override
  Future<String> guardarProducto(String uid, Producto producto) async {
    if (producto.id.isEmpty) {
      return (await crearProducto(uid, producto)).id;
    } else {
      // Una edicion conserva fechaCreacion para no mover un producto antiguo
      // al inicio de la consulta ordenada por productos nuevos primero.
      await _coleccionProductos(uid)
          .doc(producto.id)
          .update(ProductoFirestoreMapper.paraFirestore(producto));
      return producto.id;
    }
  }

  @override
  Future<Producto> crearProducto(String uid, Producto producto) async {
    final datos = ProductoFirestoreMapper.paraFirestore(producto)
      ..['fechaCreacion'] = FieldValue.serverTimestamp();
    final documento = await _coleccionProductos(uid).add(datos);
    return producto.copyWith(id: documento.id);
  }

  @override
  Future<void> eliminarProducto(String uid, String productoId) async {
    await _coleccionProductos(uid).doc(productoId).delete();
  }

  @override
  Future<void> toggleDisponible(
    String uid,
    String productoId,
    bool disponible,
  ) async {
    await _coleccionProductos(
      uid,
    ).doc(productoId).update({'disponible': disponible});
  }
}
