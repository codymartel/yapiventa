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
    final referencia = _firestore.collection('users').doc(uid);
    final existente = await referencia.get();
    if (existente.exists) {
      await referencia.set({
        'email': email,
        'terminosAceptados': true,
      }, SetOptions(merge: true));
      return;
    }
    await referencia.set({
      'email': email,
      'createdAt': Timestamp.now(),
      'setupComplete': false,
      'terminosAceptados': true,
      'webActiva': webActivaInicial,
    });
  }

  Future<void> asegurarPerfilYPlan({
    required String uid,
    required String email,
    required bool webActivaInicial,
    required int limiteProductos,
    required int minimoProductos,
  }) async {
    final perfilRef = _firestore.collection('users').doc(uid);
    final planRef = perfilRef.collection('plan').doc('actual');
    await _firestore.runTransaction((transaction) async {
      final perfil = await transaction.get(perfilRef);
      final plan = await transaction.get(planRef);
      final datosPerfil = perfil.data();
      if (datosPerfil == null) {
        transaction.set(perfilRef, {
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'setupComplete': false,
          'terminosAceptados': true,
          'webActiva': webActivaInicial,
        });
      } else {
        final actualizacion = <String, dynamic>{'email': email};
        if (!datosPerfil.containsKey('createdAt')) {
          actualizacion['createdAt'] = FieldValue.serverTimestamp();
        }
        if (!datosPerfil.containsKey('setupComplete')) {
          actualizacion['setupComplete'] = false;
        }
        if (!datosPerfil.containsKey('terminosAceptados')) {
          actualizacion['terminosAceptados'] = true;
        }
        if (!datosPerfil.containsKey('webActiva')) {
          actualizacion['webActiva'] = webActivaInicial;
        }
        transaction.update(perfilRef, actualizacion);
      }
      if (!plan.exists) {
        final hoy = DateTime.now();
        transaction.set(planRef, {
          'tipo': 'free',
          'ilimitado': true,
          'fechaInicio': FieldValue.serverTimestamp(),
          'fechaFin': Timestamp.fromDate(hoy.add(const Duration(days: 30))),
          'limiteProductos': limiteProductos,
          'minimoProductos': minimoProductos,
        });
      }
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
