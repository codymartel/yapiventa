import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/producto.dart';

class ProductosRepository {
  final FirebaseFirestore _db;

  ProductosRepository(this._db);

  CollectionReference<Map<String, dynamic>> _coleccionProductos(String uid) =>
      _db.collection('users').doc(uid).collection('productos');

  Future<List<Producto>> obtenerProductos(String uid) async {
    final snapshot = await _coleccionProductos(uid)
        .orderBy('fechaCreacion', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Producto.fromMap(doc.id, doc.data()))
        .whereType<Producto>()
        .toList();
  }

  Future<void> guardarProducto(String uid, Producto producto) async {
    final datos = producto.toMap()
      ..['fechaCreacion'] = FieldValue.serverTimestamp();

    if (producto.id.isEmpty) {
      await _coleccionProductos(uid).add(datos);
    } else {
      await _coleccionProductos(uid).doc(producto.id).update(datos);
    }
  }

  Future<void> eliminarProducto(String uid, String productoId) async {
    await _coleccionProductos(uid).doc(productoId).delete();
  }

  Future<void> toggleDisponible(String uid, String productoId, bool disponible) async {
    await _coleccionProductos(uid).doc(productoId).update({'disponible': disponible});
  }
}