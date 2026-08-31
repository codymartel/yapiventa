import 'package:cloud_firestore/cloud_firestore.dart';

// ═════════════════════════════════════════════════════════════════════════
// UserRepository
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Es el único lugar que escribe el documento de PERFIL del usuario en
// Firestore (colección `users`) y su plan inicial. No toca FirebaseAuth
// para nada — solo Firestore.
//
// QUÉ NO HACE:
// - NO crea la cuenta de login (eso es auth_repository.dart)
// - NO decide si el email ya está verificado (eso es auth_repository.dart)
// - NO sabe nada de "webActiva" ni de fechas de corte de pago
//   → eso está en features/suscripcion/
//
// CON QUÉ SE CONECTA:
// - Lo usa: features/auth/presentation/providers/auth_provider.dart
//   (el provider, DESPUÉS de confirmar con auth_repository.dart que el
//   email ya está verificado, llama a este archivo para crear el perfil)
// - Este archivo usa: el paquete cloud_firestore
//
// EQUIVALENCIA CON TU KOTLIN:
// Esto reemplaza `crearPerfilEnFirestore` y `guardarPlanFree` de tu
// AuthViewModel.kt. En tu Kotlin ambos métodos vivían pegados a la
// lógica de auth — aquí los separamos a su propio archivo porque son
// escrituras a Firestore, no a FirebaseAuth.
//
// OJO — pendiente de decisión futura (no resuelto en este archivo):
// El campo `webActiva` que se calcula aquí depende de `ConfigSuscripcion`
// (fase, fechaCorte), que todavía no migramos — eso es de
// features/suscripcion/. Por ahora, dejamos un parámetro `webActivaInicial`
// que quien llame a este repository debe calcular y pasar — así este
// archivo no necesita saber nada de suscripciones para funcionar.
// ═════════════════════════════════════════════════════════════════════════

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────
  // CREAR PERFIL EN FIRESTORE
  // ─────────────────────────────────────────────────────────────────────
  // Equivale exactamente a tu `crearPerfilEnFirestore`:
  //
  //   db.collection("users").document(uid).set(mapOf(
  //       "email" to email,
  //       "createdAt" to Timestamp.now(),
  //       "setupComplete" to false,
  //       "terminosAceptados" to true,
  //       "webActiva" to webActiva
  //   ))
  //
  // MISMOS CAMPOS, MISMOS VALORES. La única diferencia es que en tu
  // Kotlin, `webActiva` se calculaba ADENTRO de este método leyendo
  // `_configSuscripcion.value` directamente. Aquí ese cálculo no está
  // (porque ConfigSuscripcion todavía no existe en Flutter) — en su
  // lugar, este método recibe `webActivaInicial` ya calculado desde
  // afuera. Cuando migremos features/suscripcion/, el provider de auth
  // le pedirá ese valor al provider de suscripción antes de llamar aquí.
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

  // ─────────────────────────────────────────────────────────────────────
  // GUARDAR PLAN FREE INICIAL
  // ─────────────────────────────────────────────────────────────────────
  // Equivale exactamente a tu `guardarPlanFree`:
  //
  //   db.collection("users").document(uid).collection("plan")
  //     .document("actual").set(plan, SetOptions.merge())
  //
  // Mismo subcollection "plan", mismo documento "actual", mismo uso de
  // merge (para no borrar otros campos si el documento ya existiera).
  //
  // MISMOS CAMPOS que tu `hashMapOf`: tipo, ilimitado, fechaInicio,
  // fechaFin (hoy + 30 días, igual que tu Calendar.add(DAY_OF_YEAR, 30)),
  // limiteProductos y minimoProductos.
  //
  // OJO — pendiente: en tu Kotlin, `limiteProductos` y `minimoProductos`
  // venían de `AppConfig.limiteProductos` / `AppConfig.minimoProductos`.
  // Ese `AppConfig.kt` todavía no lo migramos a Flutter (sería
  // core/config/app_config.dart) — por eso aquí los recibo como
  // parámetros en vez de leerlos de un AppConfig que aún no existe.
  // Cuando migres ese archivo, puedes reemplazar los parámetros por una
  // referencia directa a AppConfig, igual que en tu Kotlin.
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

  // ─────────────────────────────────────────────────────────────────────
  // VERIFICAR SI YA EXISTE PERFIL (para Google Sign-In)
  // ─────────────────────────────────────────────────────────────────────
  // Tu Kotlin, dentro de `autenticarConGoogle`, hacía:
  //
  //   db.collection("users").document(uid).get()
  //     .addOnSuccessListener { doc -> if (doc.exists()) { ... } }
  //
  // para decidir si el login de Google era de alguien nuevo (crear
  // perfil) o de alguien que ya tenía cuenta (solo dejarlo entrar).
  // Ese "if/else" de decisión NO está aquí — vive en el provider. Este
  // método solo responde la pregunta "¿existe o no?", nada más.
  Future<bool> existePerfil(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }
}