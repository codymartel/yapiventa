import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> crearPerfilEnFirestore({
    required String uid,
    required String email,
    required bool webActivaInicial,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'createdAt': Timestamp.now(),
      'setupComplete': false,
      'terminosAceptados': true,
      'webActiva': webActivaInicial,
    });
  }

  Future<void> guardarPlanFree({
    required String uid,
    required int limiteProductos,
    required int minimoProductos,
  }) async {
    final hoy = DateTime.now();
    final fechaFin = hoy.add(const Duration(days: 30));

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('plan')
        .doc('actual')
        .set({
      'tipo': 'free',
      'ilimitado': true,
      'fechaInicio': Timestamp.fromDate(hoy),
      'fechaFin': Timestamp.fromDate(fechaFin),
      'limiteProductos': limiteProductos,
      'minimoProductos': minimoProductos,
    }, SetOptions(merge: true));
  }

  Future<bool> existePerfil(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  // ─────────────────────────────────────────────────────────────────────
  // NUEVO — LEE si setupComplete es true. Usado por
  // AuthProvider.negocioYaConfigurado() para decidir a dónde navegar
  // después de un login/registro exitoso.
  // ─────────────────────────────────────────────────────────────────────
  Future<bool> setupCompleto(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    return doc.data()?['setupComplete'] as bool? ?? false;
  }
}