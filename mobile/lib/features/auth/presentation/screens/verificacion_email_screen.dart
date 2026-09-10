import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/acceso_provider.dart';
import '../providers/auth_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// VerificacionEmailScreen
// ═════════════════════════════════════════════════════════════════════════
// Pantalla que se muestra cuando el AuthProvider está en
// AuthStatus.emailNotVerified — alguien se registró o inició sesión con
// email/contraseña pero todavía no confirmó su correo.
//
// Cuando el status pasa a success (correo confirmado + perfil creado),
// esta pantalla consulta negocioYaConfigurado() y navega a la ruta
// correcta — '/elegir-rubro' (caso normal: registro recién verificado)
// o '/home' (caso raro: alguien que ya había configurado su negocio
// antes, no verificó al toque, y ahora vuelve a confirmar).
// ═════════════════════════════════════════════════════════════════════════

class VerificacionEmailScreen extends StatefulWidget {
  const VerificacionEmailScreen({super.key});

  @override
  State<VerificacionEmailScreen> createState() =>
      _VerificacionEmailScreenState();
}

class _VerificacionEmailScreenState extends State<VerificacionEmailScreen> {
  Future<void> _revisar(AuthProvider authProvider) async {
    await authProvider.revisarSiYaVerificoEmail();
    if (!mounted || authProvider.status != AuthStatus.success) return;
    await context.read<AccesoProvider>().recargar();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
        authProvider.limpiarError();
      });
    }

    final puedeReenviar =
        authProvider.bloqueoBoton == 0 && !authProvider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        automaticallyImplyLeading: false,
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
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.blueLt,
                  size: 64,
                ),
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
                        : () => _revisar(authProvider),
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
