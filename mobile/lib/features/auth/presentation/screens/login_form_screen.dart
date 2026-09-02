import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// Migración de tu @Composable LoginScreenForm.
///
/// Esta es la única parte "delicada": la UI necesita LEER el estado del
/// AuthProvider (isLoading, errorMessage, status) para saber qué mostrar,
/// y LLAMAR a sus métodos cuando el usuario aprieta "Ingresar". Pero la
/// UI en sí sigue sin saber nada de Firebase — eso lo resuelve el provider.
class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _esEmailValido => _emailRegex.hasMatch(_emailController.text.trim());
  bool get _esPasswordValida => _passwordController.text.length >= 6;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // FIX: se extrajo la lógica del botón a su propio método, en vez de
  // dejarla inline dentro de onPressed — así es menos probable que se
  // pierda por accidente al editar el archivo, y es más fácil de leer.
  Future<void> _manejarIngresar(AuthProvider authProvider) async {
    await authProvider.iniciarSesion(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;

    if (authProvider.status == AuthStatus.success) {
      // Antes había un TODO vacío aquí — el login validaba bien pero
      // nunca navegaba a ningún lado. Ahora consulta si el negocio ya
      // está configurado y decide la ruta correcta.
      final yaConfigurado = await authProvider.negocioYaConfigurado();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        yaConfigurado ? '/home' : '/elegir-rubro',
        (route) => false,
      );
    } else if (authProvider.status == AuthStatus.emailNotVerified) {
      Navigator.of(context).pushReplacementNamed('/verificar-correo');
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch() = se redibuja cada vez que AuthProvider llama notifyListeners().
    // Es el equivalente a collectAsState() en tu Kotlin con StateFlow.
    final authProvider = context.watch<AuthProvider>();

    // Reacciona a errores nuevos mostrando un SnackBar — igual que tu
    // LaunchedEffect(errorMessage) en Compose.
    if (authProvider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage!)),
        );
        authProvider.limpiarError();
      });
    }

    final formularioValido =
        _esEmailValido && _esPasswordValida && !authProvider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
              child: Column(
                children: [
                  Text(
                    'YapiVenta',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accede a tu negocio',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: AppColors.superficie,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Iniciar sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── EMAIL ──────────────────────────────────
                        Text(
                          'Correo electrónico',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          onChanged: (_) => setState(() {}),
                          enabled: !authProvider.isLoading,
                          style: TextStyle(color: AppColors.texto),
                          decoration: InputDecoration(
                            hintText: 'tucorreo@ejemplo.com',
                            hintStyle: TextStyle(color: AppColors.dim, fontSize: 14),
                            filled: true,
                            fillColor: AppColors.card,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.blueLt, width: 1.2),
                            ),
                          ),
                        ),
                        if (_emailController.text.isNotEmpty && !_esEmailValido)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 2),
                            child: Text(
                              'Ingresa un correo válido',
                              style: TextStyle(color: AppColors.error, fontSize: 12),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // ── CONTRASEÑA ─────────────────────────────
                        Text(
                          'Contraseña',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          onChanged: (_) => setState(() {}),
                          enabled: !authProvider.isLoading,
                          obscureText: !_passwordVisible,
                          style: TextStyle(color: AppColors.texto),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: TextStyle(color: AppColors.dim, fontSize: 14),
                            filled: true,
                            fillColor: AppColors.card,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.blueLt, width: 1.2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: AppColors.muted,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                            ),
                          ),
                        ),
                        if (_passwordController.text.isNotEmpty && !_esPasswordValida)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 2),
                            child: Text(
                              'Mínimo 6 caracteres',
                              style: TextStyle(color: AppColors.error, fontSize: 12),
                            ),
                          ),

                        const SizedBox(height: 26),

                        // ── INGRESAR ───────────────────────────────
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.4),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: formularioValido
                                ? () => _manejarIngresar(authProvider)
                                : null,
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Ingresar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(
                            '¿No tienes cuenta? Regístrate',
                            style: TextStyle(color: AppColors.blueLt, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}