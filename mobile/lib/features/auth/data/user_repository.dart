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
    final datosExistentes = existente.data();

    // Estructura nueva:
    //   users/{uid}   → SOLO email, terminosAceptados, createdAt, negocioId.
    //   negocios/{id} → setupComplete, webActiva, createdAt y (a futuro)
    //                   los campos del negocio y del onboarding.
    //
    // El negocioId es independiente del UID (auto id de Firestore) y se
    // conserva si el perfil ya lo tiene asignado. Si el documento de
    // negocios ya existe, no se sobrescribe.
    final negocioIdActual = datosExistentes?['negocioId'];
    final negocioId =
        negocioIdActual is String && negocioIdActual.trim().isNotEmpty
        ? negocioIdActual
        : _firestore.collection('negocios').doc().id;

    final negocioRef = _firestore.collection('negocios').doc(negocioId);
    final negocio = await negocioRef.get();
    if (!negocio.exists) {
      await negocioRef.set({
        'propietarioUid': uid,
        'createdAt': Timestamp.now(),
        'setupComplete': false,
        'webActiva': webActivaInicial,
      });
    }

    if (!existente.exists) {
      await referencia.set({
        'email': email,
        'createdAt': Timestamp.now(),
        'terminosAceptados': true,
        'negocioId': negocioId,
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
    if (negocioIdActual is! String || negocioIdActual.trim().isEmpty) {
      actualizacion['negocioId'] = negocioId;
    }
    await referencia.set(actualizacion, SetOptions(merge: true));
  }

  Future<void> asegurarPerfilYPlan({
    required String uid,
    required String email,
    required bool webActivaInicial,
    required int limiteProductos,
    required int minimoProductos,
  }) async {
    final perfilRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final perfil = await transaction.get(perfilRef);
      final datosPerfil = perfil.data();

      // Estructura nueva:
      //   users/{uid}      → SOLO email, terminosAceptados, createdAt, negocioId.
      //   negocios/{id}    → propietarioUid, setupComplete, webActiva y (a futuro)
      //                      los campos del negocio y del onboarding.
      //   negocios/{id}/suscripcion/actual → plan (migración posterior).
      //
      // negocioId se genera de forma independiente del UID (auto id de
      // Firestore) y se conserva si el perfil ya lo tiene asignado. Los datos
      // existentes de un perfil previo no se borran ni se sobrescriben.
      final negocioIdActual = datosPerfil?['negocioId'];
      final negocioId = negocioIdActual is String && negocioIdActual.trim().isNotEmpty
          ? negocioIdActual
          : _firestore.collection('negocios').doc().id;
      final negocioRef = _firestore.collection('negocios').doc(negocioId);
      final planRef = perfilRef.collection('plan').doc('actual');

      // Todas las lecturas antes de las escrituras (requisito de Firestore).
      final negocio = await transaction.get(negocioRef);
      final plan = await transaction.get(planRef);

      if (datosPerfil == null) {
        transaction.set(perfilRef, {
          'email': email,
          'terminosAceptados': true,
          'createdAt': FieldValue.serverTimestamp(),
          'negocioId': negocioId,
        });
      } else {
        final actualizacion = <String, dynamic>{'email': email};
        if (!datosPerfil.containsKey('terminosAceptados')) {
          actualizacion['terminosAceptados'] = true;
        }
        if (!datosPerfil.containsKey('createdAt')) {
          actualizacion['createdAt'] = FieldValue.serverTimestamp();
        }
        if (negocioIdActual is! String || negocioIdActual.trim().isEmpty) {
          actualizacion['negocioId'] = negocioId;
        }
        transaction.update(perfilRef, actualizacion);
      }

      if (!negocio.exists) {
        transaction.set(negocioRef, {
          'propietarioUid': uid,
          'setupComplete': false,
          'webActiva': webActivaInicial,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
