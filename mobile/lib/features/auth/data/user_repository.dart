import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> crearPerfilEnFirestore({
    required String uid,
    required String email,
  }) async {
    final referencia = _firestore.collection('users').doc(uid);
    final existente = await referencia.get();
    final datosExistentes = existente.data();

    if (!existente.exists) {
      await referencia.set({
        'email': email,
        'createdAt': Timestamp.now(),
        'terminosAceptados': true,
      });
      return;
    }

    final actualizacion = <String, dynamic>{'email': email};
    if (!datosExistentes!.containsKey('terminosAceptados')) {
      actualizacion['terminosAceptados'] = true;
    }
    if (!datosExistentes.containsKey('createdAt')) {
      actualizacion['createdAt'] = Timestamp.now();
    }
    await referencia.set(actualizacion, SetOptions(merge: true));
  }

  Future<void> asegurarPerfilYPlan({
    required String uid,
    required String email,
    required int limiteProductos,
    required int minimoProductos,
  }) async {
    final perfilRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final perfil = await transaction.get(perfilRef);
      final datosPerfil = perfil.data();

      final planRef = perfilRef.collection('plan').doc('actual');

      // Todas las lecturas antes de las escrituras (requisito de Firestore).
      final plan = await transaction.get(planRef);

      if (datosPerfil == null) {
        transaction.set(perfilRef, {
          'email': email,
          'terminosAceptados': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final actualizacion = <String, dynamic>{'email': email};
        if (!datosPerfil.containsKey('terminosAceptados')) {
          actualizacion['terminosAceptados'] = true;
        }
        if (!datosPerfil.containsKey('createdAt')) {
          actualizacion['createdAt'] = FieldValue.serverTimestamp();
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
  // LEE si el negocio ya está configurado: resuelve `users/{uid}.negocioId`
  // y lee `negocios/{negocioId}.setupComplete`. Usado por
  // AuthProvider.negocioYaConfigurado() para decidir a dónde navegar
  // después de un login/registro exitoso.
  //
  // Devuelve false (estado seguro) si el perfil no existe, si no tiene
  // negocioId o si el documento del negocio aún no existe.
  // ─────────────────────────────────────────────────────────────────────
  Future<bool> setupCompleto(String uid) async {
    final perfil = await _firestore.collection('users').doc(uid).get();
    if (!perfil.exists) return false;

    final negocioId = perfil.data()?['negocioId'];
    if (negocioId is! String || negocioId.trim().isEmpty) return false;

    final negocio = await _firestore
        .collection('negocios')
        .doc(negocioId.trim())
        .get();
    if (!negocio.exists) return false;

    return negocio.data()?['setupComplete'] as bool? ?? false;
  }
}
