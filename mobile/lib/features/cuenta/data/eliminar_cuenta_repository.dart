import 'package:cloud_firestore/cloud_firestore.dart';

/// Borra de Firestore los datos de una cuenta (solo borrar, nada más).
///
/// Las reglas solo dejan borrar pedidos y resúmenes si el negocio está marcado
/// `eliminando`, y solo a su dueño. El orden importa: primero lo que cuelga del
/// negocio y al final el negocio, porque las reglas lo consultan.
class EliminarCuentaRepository {
  /// Tamaño de cada lote de borrado (el máximo de Firestore es 500).
  static const _lote = 400;

  final FirebaseFirestore _firestore;

  EliminarCuentaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Marca el negocio como `eliminando` y devuelve su slug (vacío si no tiene).
  /// Devuelve null si el negocio ya no existe (un intento anterior lo borró).
  Future<String?> marcarNegocioEnBorrado(String negocioId) async {
    final ref = _firestore.collection('negocios').doc(negocioId);
    final negocio = await ref.get();
    if (!negocio.exists) return null;
    await ref.update({'eliminando': true});
    final slug = negocio.data()?['slug'];
    return slug is String ? slug.trim() : '';
  }

  Future<void> borrarSubcoleccionDelNegocio(String negocioId, String nombre) {
    return _borrarColeccion(
      _firestore.collection('negocios').doc(negocioId).collection(nombre),
    );
  }

  /// Borra la página pública. Si ya no existe, las reglas lo rechazan (no hay
  /// documento que comprobar): eso no es un error.
  Future<void> borrarPaginaPublica(String slug) async {
    try {
      await _firestore.collection('negocios_publicos').doc(slug).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
  }

  Future<void> borrarNegocio(String negocioId) {
    return _firestore.collection('negocios').doc(negocioId).delete();
  }

  /// Borra el plan y el perfil del usuario.
  Future<void> borrarPerfil(String uid) async {
    final usuario = _firestore.collection('users').doc(uid);
    await _borrarColeccion(usuario.collection('plan'));
    await usuario.delete();
  }

  /// Borra una colección de [_lote] en [_lote] documentos. Si un lote falla
  /// (por ejemplo por el límite de consultas de las reglas), borra ese tramo
  /// de uno en uno.
  Future<void> _borrarColeccion(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    while (true) {
      final tramo = await col.limit(_lote).get();
      if (tramo.docs.isEmpty) return;
      try {
        final lote = _firestore.batch();
        for (final doc in tramo.docs) {
          lote.delete(doc.reference);
        }
        await lote.commit();
      } on FirebaseException {
        for (final doc in tramo.docs) {
          await doc.reference.delete();
        }
      }
      if (tramo.docs.length < _lote) return;
    }
  }
}
