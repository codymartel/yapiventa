import 'package:firebase_auth/firebase_auth.dart';

// ═════════════════════════════════════════════════════════════════════════
// AuthRepository
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Es la ÚNICA clase de toda la app que llama directamente a
// `FirebaseAuth.instance`. Todo lo demás (pantallas, providers) le pide
// cosas a esta clase, nunca hablan con FirebaseAuth directo.
//
// QUÉ NO HACE (para que sepas dónde buscar el resto):
// - NO guarda nada en Firestore (crear perfil de usuario, plan free, etc.)
//   → eso está en features/auth/data/user_repository.dart
// - NO maneja el reloj de bloqueo de 10s del botón "reenviar correo"
//   → eso está en features/auth/presentation/providers/auth_provider.dart
// - NO sabe nada de suscripciones ni de "webActiva"
//   → eso está en features/suscripcion/
//
// CON QUÉ SE CONECTA:
// - Lo usa: features/auth/presentation/providers/auth_provider.dart
//   (el provider llama a los métodos de aquí y decide qué hacer con
//   el resultado — mostrar error, avanzar de pantalla, etc.)
// - Este archivo usa: el paquete firebase_auth (nada más, ninguna otra
//   parte de tu proyecto)
//
// EQUIVALENCIA CON TU KOTLIN:
// Esto reemplaza la parte de AuthViewModel.kt que llamaba a
// `FirebaseAuth.getInstance()` — o sea `auth.signInWithEmailAndPassword`,
// `auth.createUserWithEmailAndPassword`, etc. La lógica de qué hacer
// con el resultado (guardar en StateFlow, etc.) NO está aquí, está en
// auth_provider.dart.
// ═════════════════════════════════════════════════════════════════════════

class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  // Si no le pasas nada, usa la instancia normal de Firebase.
  // Poder pasarle una distinta sirve para tests (no es necesario usarlo
  // ahora, solo lo dejamos preparado).
  AuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `iniciarSesion` en Kotlin, SOLO la parte que llama a
  // Firebase:
  //   auth.signInWithEmailAndPassword(email, password)
  //
  // Lo que en Kotlin pasaba DESPUÉS del login (revisar si el email está
  // verificado, poner el AuthState en Success, etc.) NO está aquí —
  // eso lo decide auth_provider.dart cuando reciba el resultado de este
  // método.
  //
  // Si el login falla, lanza FirebaseAuthException — el provider la
  // atrapa y decide qué mensaje mostrar (ese mapeo de mensajes tampoco
  // va aquí, va en el provider).
  Future<User?> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  // ─────────────────────────────────────────────────────────────────────
  // REGISTRO
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `registrarUsuario` en Kotlin, incluyendo el mismo
  // manejo de "el correo ya existe" que tenías:
  //
  //   1. Intenta crear la cuenta con auth.createUserWithEmailAndPassword
  //   2. Si Firebase dice que el correo YA existe (FirebaseAuthException
  //      con código 'email-already-in-use' — esto es lo mismo que en tu
  //      Kotlin capturabas como FirebaseAuthUserCollisionException),
  //      intenta hacer login con esas mismas credenciales.
  //   3. Si ese login funciona Y el correo TODAVÍA no está verificado,
  //      se trata como una cuenta a medio registrar: se le reenvía el
  //      correo de verificación y se devuelve el user (igual que tu
  //      bloque `enviarYVerificar(email)` dentro del if de colisión).
  //   4. Si el correo YA estaba verificado (o la contraseña no coincidía),
  //      se relanza el error para arriba — el provider es quien decide
  //      mostrar "ya existe, inicia sesión" (en tu Kotlin ese mensaje
  //      estaba puesto directo aquí; ahora vive en el provider).
  //
  // Aquí SÍ se manda el correo de verificación al crear la cuenta nueva
  // (igual que tu enviarYVerificar), porque es un efecto directo de
  // Firebase Auth, no de Firestore.
  Future<User?> registrarse({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.sendEmailVerification();
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
          return user;
        }
        rethrow;
      }
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // REENVIAR CORREO DE VERIFICACIÓN
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `reenviarEmailDeVerificacion`. Solo manda el correo de
  // nuevo si el usuario actual existe y todavía no está verificado.
  //
  // El reloj de 10 segundos que en Kotlin bloqueaba el botón después de
  // llamar esto (`iniciarRelojBloqueo(10)`) NO está aquí — eso es estado
  // de UI y vive en auth_provider.dart, que es quien llama a este método
  // y LUEGO arranca su propio contador.
  Future<void> enviarVerificacionEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // REVISAR SI YA VERIFICÓ EL CORREO
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a la parte de Firebase de tu `revisarSiYaVerificoEmail`:
  //
  //   user.reload() → luego user.isEmailVerified
  //
  // Firebase no actualiza el estado de "verificado" solo — hay que
  // pedirle explícitamente un reload antes de preguntar. Este método
  // hace exactamente eso y devuelve true/false.
  //
  // Lo que en tu Kotlin pasaba SI estaba verificado (crear el perfil en
  // Firestore con crearPerfilEnFirestore, guardar el plan con
  // guardarPlanFree, cambiar el AuthState a Success) NO está aquí —
  // eso lo hace el provider, llamando primero a este método y luego,
  // si devuelve true, llamando a user_repository.dart para crear el
  // perfil.
  Future<bool> emailEstaVerificado() async {
    await _firebaseAuth.currentUser?.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────
  // CANCELAR REGISTRO (si el usuario se arrepiente antes de verificar)
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a tu `cancelarYLimpiarTodo`. Si el usuario actual todavía
  // no verificó su correo, borra la cuenta de Firebase Auth por completo
  // (para que pueda intentar registrarse de nuevo desde cero con el
  // mismo correo). Si ya estaba verificado, no borra nada, solo cierra
  // sesión.
  //
  // La parte de tu Kotlin que llamaba a `limpiarEstadoInterno()`
  // (resetear _errorMessage y _authState) NO está aquí — eso es estado
  // del provider, no de Firebase.
  Future<void> cancelarRegistroSiNoVerificado() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.delete();
    }
    await _firebaseAuth.signOut();
  }

  // ─────────────────────────────────────────────────────────────────────
  // GOOGLE SIGN-IN
  // ─────────────────────────────────────────────────────────────────────
  // Equivale a la parte de Firebase de tu `autenticarConGoogle`:
  //
  //   GoogleAuthProvider.getCredential(idToken, null)
  //   auth.signInWithCredential(credential)
  //
  // En Flutter, `GoogleAuthProvider.credential()` pide tanto idToken
  // como accessToken (en Kotlin solo pasabas el idToken) — es una
  // diferencia del SDK, no un cambio de lógica tuya.
  //
  // Todo lo que en tu Kotlin pasaba DESPUÉS de este login (revisar si
  // el uid ya existe en Firestore, decidir si es login o registro,
  // crear perfil si es nuevo) NO está aquí — eso vive en el provider,
  // que llama primero a este método y después consulta
  // user_repository.dart para saber si el uid ya tiene documento.
  Future<User?> autenticarConGoogle(String idToken, String accessToken) async {
    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return userCredential.user;
  }

  // ─────────────────────────────────────────────────────────────────────
  // CERRAR SESIÓN
  // ─────────────────────────────────────────────────────────────────────
  // No existía como método separado en tu Kotlin (estaba mezclado dentro
  // de cancelarYLimpiarTodo), pero se necesita como su propia función
  // para cuando el usuario simplemente haga logout desde, por ejemplo,
  // una pantalla de perfil más adelante.
  Future<void> cerrarSesion() => _firebaseAuth.signOut();

  // ─────────────────────────────────────────────────────────────────────
  // ACCESOS DIRECTOS
  // ─────────────────────────────────────────────────────────────────────
  // usuarioActual: para preguntar "¿hay alguien logueado ahora mismo?"
  // sin tener que esperar un Future.
  //
  // cambiosDeAuth: un Stream que avisa cada vez que alguien inicia o
  // cierra sesión — útil más adelante para, por ejemplo, mandar
  // automáticamente a Home si ya hay sesión activa al abrir la app.
  User? get usuarioActual => _firebaseAuth.currentUser;

  Stream<User?> get cambiosDeAuth => _firebaseAuth.authStateChanges();
}