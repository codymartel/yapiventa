import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/producto.dart';
import '../domain/repositories/repositorio_productos.dart';

// Una pagina conserva los documentos ya convertidos y el cursor real de
// Firestore. La pantalla nunca calcula posiciones: entrega este cursor al
// repositorio para continuar exactamente despues del ultimo documento leido.
class PaginaProductos {
  final List<Producto> productos;
  final DocumentSnapshot<Map<String, dynamic>>? ultimoDocumento;
  final bool hayMas;

  const PaginaProductos({
    required this.productos,
    required this.ultimoDocumento,
    required this.hayMas,
  });
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
  Future<PaginaProductos> obtenerProductos(
    String uid, {
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int limite = 10,
  }) async {
    Query<Map<String, dynamic>> query = _coleccionProductos(
      uid,
    ).orderBy('fechaCreacion', descending: true);

    if (despuesDe != null) {
      query = query.startAfterDocument(despuesDe);
    }

    // Se pide un documento adicional solo para saber si existe otra página.
    query = query.limit(limite + 1);

    final snapshot = await query.get();
    final documentosPagina = snapshot.docs.take(limite).toList();

    final productos = documentosPagina
        .map((documento) {
          return Producto.fromMap(documento.id, documento.data());
        })
        .whereType<Producto>()
        .toList();

    return PaginaProductos(
      productos: productos,
      ultimoDocumento: documentosPagina.isNotEmpty
          ? documentosPagina.last
          : null,
      hayMas: snapshot.docs.length > limite,
    );
  }

  Future<String> guardarProducto(String uid, Producto producto) async {
    if (producto.id.isEmpty) {
      return (await crearProducto(uid, producto)).id;
    } else {
      // Una edicion conserva fechaCreacion para no mover un producto antiguo
      // al inicio de la consulta ordenada por productos nuevos primero.
      await _coleccionProductos(uid).doc(producto.id).update(producto.toMap());
      return producto.id;
    }
  }

  @override
  Future<Producto> crearProducto(String uid, Producto producto) async {
    final datos = producto.toMap()
      ..['fechaCreacion'] = FieldValue.serverTimestamp();
    final documento = await _coleccionProductos(uid).add(datos);
    return producto.copyWith(id: documento.id);
  }

  Future<void> eliminarProducto(String uid, String productoId) async {
    await _coleccionProductos(uid).doc(productoId).delete();
  }

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
