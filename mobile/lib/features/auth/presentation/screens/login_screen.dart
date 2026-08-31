import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/beneficio_item.dart';
import 'login_form_screen.dart';
import 'register_screen.dart';

/// Migración de tu @Composable LoginScreen(onIngresar, onRegistrarse).
///
/// En pantallas anchas (PC) usa layout tipo split-screen: contenido a la
/// izquierda, panel visual a la derecha — igual al patrón de landing de
/// apps tipo Claude/Linear. En mobile colapsa a una sola columna.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final esAncho = constraints.maxWidth >= 900;

            if (esAncho) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 32,
                          ),
                          child: _ContenidoLogin(isSmallScreen: false),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _PanelVisual(),
                    ),
                  ),
                ],
              );
            }

            final isSmallScreen = constraints.maxHeight < 680 || constraints.maxWidth < 360;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, isSmallScreen ? 32 : 48, 24, 32),
              child: _ContenidoLogin(isSmallScreen: isSmallScreen),
            );
          },
        ),
      ),
    );
  }
}

/// Panel visual decorativo — lado derecho en pantallas anchas.
/// Reemplaza esto por una imagen real (Image.asset/Image.network) cuando
/// tengas fotos del producto o del negocio.
class _PanelVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navy,
            AppColors.fondo,
          ],
        ),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 40,
            left: 40,
            child: _Chip(icono: '📦', texto: 'Producto agregado', delta: '+12 hoy'),
          ),
          Positioned(
            top: 140,
            right: 50,
            child: _Chip(icono: '📊', texto: 'Ventas del mes', delta: '+18%'),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.blueLt.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🛡', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Todo tu negocio\nen un solo lugar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            left: 50,
            child: _Chip(icono: '📱', texto: 'Pedido nuevo', delta: 'WhatsApp'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String icono;
  final String texto;
  final String delta;

  const _Chip({required this.icono, required this.texto, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icono, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto, style: TextStyle(color: AppColors.texto, fontSize: 12)),
              Text(
                delta,
                style: TextStyle(
                  color: AppColors.blueLt,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Contenido compartido: logo, titular, beneficios y botones.
/// Se usa igual en el layout de PC (columna izquierda) y en mobile (columna única).
class _ContenidoLogin extends StatelessWidget {
  final bool isSmallScreen;

  const _ContenidoLogin({required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    final contentSpacing = isSmallScreen ? 24.0 : 40.0;
    final buttonHeight = isSmallScreen ? 52.0 : 56.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LOGO ──────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.blueLt.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              alignment: Alignment.center,
              child: const Text('🛡', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YapiVenta',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.texto,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Gestión de negocios locales',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),

        SizedBox(height: isSmallScreen ? 32 : 48),

        // ── TITULAR ───────────────────────────────────────────
        Text(
          'Tu negocio,\nbajo control.',
          style: TextStyle(
            fontSize: isSmallScreen ? 26 : 34,
            height: isSmallScreen ? 1.23 : 1.2,
            fontWeight: FontWeight.w800,
            color: AppColors.texto,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Mejora tu experiencia vendiendo más y mejor cada día.',
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 15,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),

        SizedBox(height: isSmallScreen ? 28 : 36),

        // ── BENEFICIOS ────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              const BeneficioItem(icono: '📦', texto: 'Gestión de productos y stock'),
              Divider(color: AppColors.border, height: 0.5),
              const BeneficioItem(icono: '🌐', texto: 'Página web automática con tu link'),
              Divider(color: AppColors.border, height: 0.5),
              const BeneficioItem(icono: '📊', texto: 'Estadísticas de tu negocio'),
              Divider(color: AppColors.border, height: 0.5),
              const BeneficioItem(icono: '📱', texto: 'Pedidos por WhatsApp directo'),
            ],
          ),
        ),

        SizedBox(height: contentSpacing),

        // ── BOTONES ───────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginFormScreen()),
              );
            },
            child: Text(
              'Ingresar con mi cuenta',
              style: TextStyle(
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              foregroundColor: AppColors.texto,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            child: Text(
              'Crear cuenta nueva',
              style: TextStyle(
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Gratis para siempre',
            style: TextStyle(fontSize: 11, color: AppColors.dim),
          ),
        ),
      ],
    );
  }
}