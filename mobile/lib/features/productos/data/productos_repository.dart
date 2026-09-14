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

  /// Resuelve el id del negocio leyendo `users/{uid}.negocioId`.
  ///
  /// No escribe nada en users/{uid}: solo lo lee. Si el perfil no tiene
  /// negocioId (por ejemplo un usuario antiguo sin aprovisionar), lanza un
  /// error claro y la operación no se ejecuta sobre una ruta incorrecta.
  Future<String> _obtenerNegocioId(String uid) async {
    final perfil = await _db.collection('users').doc(uid).get();
    final negocioId = perfil.data()?['negocioId'];
    if (negocioId is! String || negocioId.trim().isEmpty) {
      throw StateError(
        'No se encontró un negocioId para el usuario "$uid". '
        'Asegúrate de que el registro esté completo antes de operar los productos.',
      );
    }
    return negocioId.trim();
  }

  /// Los productos viven bajo `negocios/{negocioId}/productos`; el id del
  /// negocio se resuelve desde el perfil del usuario.
  Future<CollectionReference<Map<String, dynamic>>> _coleccionProductos(
    String uid,
  ) async {
    final negocioId = await _obtenerNegocioId(uid);
    return _db.collection('negocios').doc(negocioId).collection('productos');
  }

  // Equivale a pedir una pagina manual del catalogo: la primera consulta
  // trae los 10 productos mas recientes y las siguientes continuan desde
  // [despuesDe], sin volver a leer los documentos de paginas anteriores.
  @override
  Future<PaginaProductos> obtenerPaginaProductos(
    String uid, {
    CursorProductos? despuesDe,
    int limite = 10,
  }) async {
    final coleccion = await _coleccionProductos(uid);
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
  Future<String> guardarProducto(String uid, Producto producto) async {
    if (producto.id.isEmpty) {
      return (await crearProducto(uid, producto)).id;
    } else {
      final negocioId = await _obtenerNegocioId(uid);
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
  Future<Producto> crearProducto(String uid, Producto producto) async {
    final negocioId = await _obtenerNegocioId(uid);
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
  Future<void> eliminarProducto(String uid, String productoId) async {
    final coleccion = await _coleccionProductos(uid);
    await coleccion.doc(productoId).delete();
  }

  @override
  Future<void> toggleDisponible(
    String uid,
    String productoId,
    bool disponible,
  ) async {
    final coleccion = await _coleccionProductos(uid);
    await coleccion.doc(productoId).update({'disponible': disponible});
  }
}
