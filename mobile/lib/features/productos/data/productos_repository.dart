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

  /// Los productos viven bajo `negocios/{negocioId}/productos`. El `negocioId`
  /// ya viene resuelto (se leyó users/{uid} una sola vez al iniciar sesión) y
  /// se reutiliza en todas las operaciones, sin releer `users/{uid}`.
  CollectionReference<Map<String, dynamic>> _coleccionProductos(
    String negocioId,
  ) {
    final negocioIdLimpio = negocioId.trim();
    if (negocioIdLimpio.isEmpty) {
      throw StateError(
        'No se encontró un negocioId para operar los productos. '
        'Asegúrate de que el registro esté completo antes de operar los productos.',
      );
    }
    return _db
        .collection('negocios')
        .doc(negocioIdLimpio)
        .collection('productos');
  }

  // Equivale a pedir una pagina manual del catalogo: la primera consulta
  // trae los 10 productos mas recientes y las siguientes continuan desde
  // [despuesDe], sin volver a leer los documentos de paginas anteriores.
  @override
  Future<PaginaProductos> obtenerPaginaProductos(
    String negocioId, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) async {
    final coleccion = _coleccionProductos(negocioId);
    Query<Map<String, dynamic>> query = coleccion.orderBy(
      'fechaCreacion',
      descending: true,
    );

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
  Future<String> guardarProducto(String negocioId, Producto producto) async {
    if (producto.id.isEmpty) {
      return (await crearProducto(negocioId, producto)).id;
    } else {
      final datos = ProductoFirestoreMapper.paraFirestore(producto)
        ..['negocioId'] = negocioId;
      // Una edicion conserva fechaCreacion para no mover un producto antiguo
      // al inicio de la consulta ordenada por productos nuevos primero.
      await _db
          .collection('negocios')
          .doc(negocioId)
          .collection('productos')
          .doc(producto.id)
          .update(datos);
      return producto.id;
    }
  }

  @override
  Future<Producto> crearProducto(String negocioId, Producto producto) async {
    final datos = ProductoFirestoreMapper.paraFirestore(producto)
      ..['negocioId'] = negocioId
      ..['fechaCreacion'] = FieldValue.serverTimestamp();
    final documento = await _db
        .collection('negocios')
        .doc(negocioId)
        .collection('productos')
        .add(datos);
    return producto.copyWith(id: documento.id, negocioId: negocioId);
  }

  @override
  Future<void> eliminarProducto(String negocioId, String productoId) async {
    final coleccion = _coleccionProductos(negocioId);
    await coleccion.doc(productoId).delete();
  }

  @override
  Future<void> toggleDisponible(
    String negocioId,
    String productoId,
    bool disponible,
  ) async {
    final coleccion = _coleccionProductos(negocioId);
    await coleccion.doc(productoId).update({'disponible': disponible});
  }
}
