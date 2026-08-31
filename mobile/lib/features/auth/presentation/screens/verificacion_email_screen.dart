import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// VerificacionEmailScreen
// ═════════════════════════════════════════════════════════════════════════
// Pantalla que se muestra cuando el AuthProvider está en
// AuthStatus.emailNotVerified — o sea, alguien se registró o inició
// sesión con email/contraseña pero todavía no confirmó su correo.
//
// Google NUNCA llega a esta pantalla — su correo ya viene verificado
// por Google, así que auth_provider.dart nunca pone emailNotVerified
// para ese flujo.
//
// Botones (equivalentes a tu Kotlin):
//   - "Ya verifiqué mi correo" → revisarSiYaVerificoEmail()
//   - "Reenviar correo"        → reenviarEmailDeVerificacion()
//                                 (deshabilitado mientras bloqueoBoton > 0)
//   - "Cancelar"               → cancelarRegistro() y vuelve al login
//
// Cuando el provider pasa a AuthStatus.success, esta pantalla navega
// sola a Home (por ahora con un placeholder, hasta que migres
// home_screen.dart de verdad).
// ═════════════════════════════════════════════════════════════════════════

class VerificacionEmailScreen extends StatelessWidget {
  const VerificacionEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Reacciona a mensajes nuevos (éxito de reenvío, o errores) con un
    // SnackBar — mismo patrón que usamos en login_form_screen.dart.
    if (authProvider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage!)),
        );
        authProvider.limpiarError();
      });
    }

    // Cuando ya verificó y el perfil se creó, el provider pasa a
    // success — navegamos a Home. pushReplacement para que no pueda
    // volver "atrás" a esta pantalla con el botón físico/gesto.
    if (authProvider.status == AuthStatus.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const _HomePlaceholder()),
        );
      });
    }

    final puedeReenviar =
        authProvider.bloqueoBoton == 0 && !authProvider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        automaticallyImplyLeading: false, // no queremos flecha "atrás" aquí
        title: Text(
          'Verifica tu correo',
          style: TextStyle(color: AppColors.texto),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    color: AppColors.blueLt, size: 64),
                const SizedBox(height: 20),
                Text(
                  'Revisa tu bandeja de entrada',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Te enviamos un correo de verificación. '
                  'Ábrelo y confirma tu cuenta antes de continuar.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // ── YA VERIFIQUÉ ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: authProvider.isLoading
                        ? null
                        : () => authProvider.revisarSiYaVerificoEmail(),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Ya verifiqué mi correo'),
                  ),
                ),

                const SizedBox(height: 14),

                // ── REENVIAR (con contador) ──────────────────────────
                TextButton(
                  onPressed: puedeReenviar
                      ? () => authProvider.reenviarEmailDeVerificacion()
                      : null,
                  child: Text(
                    authProvider.bloqueoBoton > 0
                        ? 'Reenviar correo (${authProvider.bloqueoBoton}s)'
                        : 'Reenviar correo',
                    style: TextStyle(
                      color: puedeReenviar ? AppColors.blueLt : AppColors.dim,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── CANCELAR ──────────────────────────────────────
                TextButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          await authProvider.cancelarRegistro();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                  child: Text(
                    'Cancelar y volver',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Placeholder temporal de Home — SOLO para poder probar el flujo completo
// de login/registro hasta acá. Reemplazar por el home_screen.dart real
// cuando migres esa feature.
// ─────────────────────────────────────────────────────────────────────────
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Center(
        child: Text(
          '¡Bienvenido! (Home pendiente de migrar)',
          style: TextStyle(color: AppColors.texto, fontSize: 18),
        ),
      ),
    );
  }
}