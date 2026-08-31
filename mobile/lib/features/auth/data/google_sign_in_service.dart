import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

// ═════════════════════════════════════════════════════════════════════════
// GoogleSignInService
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Es el único lugar que habla directamente con el paquete google_sign_in.
// Su trabajo es UNA sola cosa: mostrar el selector de cuenta de Google y
// devolver el idToken + accessToken que auth_repository.dart necesita
// para autenticarse con Firebase.
//
// QUÉ NO HACE:
// - NO habla con FirebaseAuth (eso es auth_repository.dart)
// - NO decide si es login o registro (eso es auth_provider.dart)
// - NO crea nada en Firestore (eso es user_repository.dart)
//
// CON QUÉ SE CONECTA:
// - Lo usa: las pantallas (login_form_screen.dart, register_screen.dart)
//   cuando el usuario aprieta el botón "Continuar con Google". La
//   pantalla llama primero a este servicio para obtener los tokens, y
//   LUEGO se los pasa a authProvider.autenticarConGoogle(idToken,
//   accessToken, esModoRegistro: ...).
//
// PLATAFORMAS CUBIERTAS: Android y Web (las que se priorizaron). El
// paquete google_sign_in detecta automáticamente en qué plataforma
// corre y usa el flujo correcto por debajo — no hay que escribir código
// distinto a mano para cada una. Lo único que cambia según la
// plataforma es CÓMO se inicializa internamente:
//
//   - clientId: lo necesita google_sign_in_web para inicializar el SDK
//     de Google Identity Services en el navegador. Si no se manda en
//     web, el plugin revienta con un assertFailed al abrir el selector.
//   - serverClientId: lo necesita Android para que el idToken que
//     devuelve Google tenga la audiencia correcta y sea válido al
//     canjearlo con Firebase. EN WEB este parámetro debe ir null a la
//     fuerza — google_sign_in_web (0.12.4+4) tiene un assert que revienta
//     si serverClientId no es null, con el mensaje "serverClientId is
//     not supported on Web.".
//
// Ambos valores usan el mismo Web Client ID (client_type: 3) sacado
// del google-services.json / Firebase console — solo que en Web y
// Android van a parámetros distintos y son mutuamente excluyentes.
//
// Windows queda fuera — necesitaría un Client ID de tipo Desktop
// distinto, que no se ha configurado (Windows Desktop sigue pausado).
// ═════════════════════════════════════════════════════════════════════════

class GoogleSignInService {
  // Web Client ID (client_type: 3) que obtuvimos del
  // google-services.json — se usa tanto en clientId (web) como en
  // serverClientId (Android), pero nunca los dos a la vez.
  static const _webClientId =
      '359947632947-ld74sn7ih88gll1p3oo9km24lbsi516s.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn;

  GoogleSignInService()
      : _googleSignIn = GoogleSignIn(
          // Necesario en Web: sin esto, google_sign_in_web no puede
          // inicializar el SDK de Google Identity Services y truena
          // con un assertFailed al llamar signIn().
          clientId: kIsWeb ? _webClientId : null,
          // Necesario en Android para que el idToken devuelto sea
          // válido al canjearlo con Firebase. En Web DEBE ser null:
          // el plugin explota si detecta cualquier valor aquí.
          serverClientId: kIsWeb ? null : _webClientId,
          scopes: ['email'],
        );

  /// Muestra el selector de cuenta de Google y devuelve un objeto con
  /// el idToken y accessToken listos para pasarle a
  /// AuthRepository.autenticarConGoogle(). Devuelve null si el usuario
  /// cierra el selector sin elegir cuenta (cancela el login) — en ese
  /// caso la pantalla simplemente no hace nada, no es un error.
  Future<GoogleTokens?> iniciarSesionConGoogle() async {
    final cuenta = await _googleSignIn.signIn();
    if (cuenta == null) {
      // El usuario canceló el selector — no es un error, solo no hizo nada.
      return null;
    }

    final autenticacion = await cuenta.authentication;

    if (autenticacion.idToken == null || autenticacion.accessToken == null) {
      // Caso raro, pero posible: Google no devolvió los tokens esperados.
      return null;
    }

    return GoogleTokens(
      idToken: autenticacion.idToken!,
      accessToken: autenticacion.accessToken!,
    );
  }

  /// Cierra la sesión de Google (no la de Firebase — esa la maneja
  /// AuthRepository.cerrarSesion() por separado). Útil para permitir
  /// que la próxima vez se pueda elegir una cuenta distinta de Google.
  Future<void> cerrarSesionGoogle() => _googleSignIn.signOut();
}

/// Contenedor simple para los dos valores que necesita
/// AuthRepository.autenticarConGoogle().
class GoogleTokens {
  final String idToken;
  final String accessToken;

  GoogleTokens({required this.idToken, required this.accessToken});
}