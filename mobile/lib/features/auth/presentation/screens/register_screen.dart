import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/google_sign_in_service.dart';
import '../providers/auth_provider.dart';

/// Migración de tu @Composable RegisterScreen.
///
/// Igual que LoginFormScreen: esta pantalla solo LEE el estado del
/// AuthProvider y LLAMA a registrarse() o autenticarConGoogle(). No sabe
/// nada de Firebase directamente — el botón de Google usa
/// GoogleSignInService solo para OBTENER los tokens, y se los pasa al
/// provider, que es quien decide qué hacer con ellos.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _aceptoTerminos = false;

  // NUEVO — el servicio que obtiene los tokens de Google. Se crea una
  // sola vez por pantalla, no en cada build.
  final _googleSignInService = GoogleSignInService();

  final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _esEmailValido => _emailRegex.hasMatch(_emailController.text.trim());
  bool get _esPasswordValida => _passwordController.text.length >= 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _abrirDialogoTerminos();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _abrirDialogoTerminos() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TerminosDialog(
        onAceptar: () {
          setState(() => _aceptoTerminos = true);
          Navigator.pop(context);
        },
        onCerrar: () {
          Navigator.pop(context);
          if (!_aceptoTerminos) Navigator.pop(context);
        },
      ),
    );
  }

  // NUEVO — maneja el botón de Google: pide los tokens al servicio y,
  // si el usuario no canceló, se los pasa al provider en modo registro.
  Future<void> _registrarseConGoogle() async {
    final authProvider = context.read<AuthProvider>();
    final tokens = await _googleSignInService.iniciarSesionConGoogle();

    if (tokens == null) {
      // Usuario canceló el selector de cuenta — no hacemos nada, no es
      // un error que deba mostrarse.
      return;
    }

    if (!mounted) return;
    await authProvider.autenticarConGoogle(
      tokens.idToken,
      tokens.accessToken,
      esModoRegistro: true,
    );
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

    return _construirPantalla(authProvider);
  }

  Widget _construirPantalla(AuthProvider authProvider) {
    final registroHabilitado =
        _esEmailValido &&
        _esPasswordValida &&
        _aceptoTerminos &&
        !authProvider.isLoading;

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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Crea tu cuenta',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ingresa tus datos para comenzar',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
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
                        // ── NUEVO — GOOGLE ─────────────────────────
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : _registrarseConGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'G',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4285F4),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Continuar con Google',
                                  style: TextStyle(
                                    color: const Color(0xFF1C2A3A),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '🔒 Recomendado · más seguro y rápido',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.blueLt,
                            fontSize: 11,
                          ),
                        ),

                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                'o con correo',
                                style: TextStyle(
                                  color: AppColors.dim,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: AppColors.border)),
                          ],
                        ),
                        const SizedBox(height: 18),

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
                            hintStyle: TextStyle(
                              color: AppColors.dim,
                              fontSize: 14,
                            ),
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
                              borderSide: BorderSide(
                                color: AppColors.blueLt,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        if (_emailController.text.isNotEmpty && !_esEmailValido)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 2),
                            child: Text(
                              'Ingresa un correo válido',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
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
                            hintText: 'Mínimo 6 caracteres',
                            hintStyle: TextStyle(
                              color: AppColors.dim,
                              fontSize: 14,
                            ),
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
                              borderSide: BorderSide(
                                color: AppColors.blueLt,
                                width: 1.2,
                              ),
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
                        if (_passwordController.text.isNotEmpty &&
                            !_esPasswordValida)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 2),
                            child: Text(
                              'Mínimo 6 caracteres',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // ── Estado términos ────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _aceptoTerminos
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: _aceptoTerminos
                                    ? Colors.green
                                    : AppColors.muted,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _aceptoTerminos
                                      ? 'Términos aceptados'
                                      : 'Términos pendientes',
                                  style: TextStyle(
                                    color: _aceptoTerminos
                                        ? Colors.green
                                        : AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _abrirDialogoTerminos,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Ver',
                                  style: TextStyle(
                                    color: AppColors.blueLt,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── REGISTRAR ──────────────────────────────
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              disabledBackgroundColor: AppColors.navy
                                  .withValues(alpha: 0.4),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: registroHabilitado
                                ? () => authProvider.registrarse(
                                    _emailController.text.trim(),
                                    _passwordController.text,
                                  )
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
                                    'SIGUIENTE: Verificar Correo →',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
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
                            '¿Ya tienes cuenta? Inicia sesión',
                            style: TextStyle(
                              color: AppColors.blueLt,
                              fontSize: 13,
                            ),
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

// ─── Diálogo de Términos (con el fix del overflow ya aplicado) ─────
class _TerminosDialog extends StatefulWidget {
  final VoidCallback onAceptar;
  final VoidCallback onCerrar;

  const _TerminosDialog({required this.onAceptar, required this.onCerrar});

  @override
  State<_TerminosDialog> createState() => _TerminosDialogState();
}

class _TerminosDialogState extends State<_TerminosDialog> {
  final _scrollController = ScrollController();
  bool _llegoAlFinal = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  void _checkScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final sinScroll = _scrollController.position.maxScrollExtent == 0;
    final llego =
        sinScroll ||
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 40;
    if (llego != _llegoAlFinal) setState(() => _llegoAlFinal = llego);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Términos y Condiciones',
        style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold),
      ),
      // FIX del overflow: se limita la altura total del contenido a un
      // porcentaje de la pantalla, y el scroll usa Flexible en vez de
      // una altura fija de 380 — así se adapta a ventanas cortas.
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_llegoAlFinal)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '📜 Desplázate hasta el final para poder aceptar',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
              Flexible(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      _terminosTexto,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _llegoAlFinal ? 1 : null,
                color: _llegoAlFinal ? Colors.green : AppColors.error,
                backgroundColor: AppColors.border,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _llegoAlFinal
                      ? '✓ Has leído todos los términos'
                      : 'Sigue leyendo para poder aceptar…',
                  style: TextStyle(
                    color: _llegoAlFinal ? Colors.green : AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCerrar,
          child: Text('Cerrar', style: TextStyle(color: AppColors.muted)),
        ),
        ElevatedButton(
          onPressed: _llegoAlFinal ? widget.onAceptar : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            disabledBackgroundColor: AppColors.border,
          ),
          child: Text(
            _llegoAlFinal ? 'ENTENDIDO Y ACEPTO' : '↓ Sigue leyendo…',
          ),
        ),
      ],
    );
  }
}

const _terminosTexto = '''
Al registrarte y usar YapiVenta en Huánuco, Perú, aceptas expresamente los siguientes términos:

1. DATOS PERSONALES Y DEL NEGOCIO
Recopilamos y almacenamos: nombre del negocio, correo electrónico, número de WhatsApp/teléfono, dirección, rubro, horarios, redes sociales, fotografías de productos, precios y cualquier otro dato que ingreses voluntariamente. Estos datos se almacenan en Firebase (Google LLC) bajo estándares de seguridad internacionales. No vendemos ni compartimos tu información con terceros sin tu consentimiento, salvo obligación legal.

2. FOTOGRAFÍAS E IMÁGENES
Las imágenes que subas a YapiVenta se almacenan en Cloudinary. Al subirlas, declaras que eres propietario o tienes los derechos para usarlas. YapiVenta no se responsabiliza por el uso de imágenes con derechos de autor subidas por el usuario.

3. PRECIOS Y PRODUCTOS
El usuario es el único responsable de la veracidad, exactitud y legalidad de los productos, precios y descripciones publicados en su catálogo. YapiVenta actúa únicamente como plataforma de exhibición y no verifica ni garantiza la exactitud de dicha información.

4. TRANSACCIONES Y PAGOS
YapiVenta facilita el contacto entre compradores y vendedores a través de WhatsApp, pero NO interviene, procesa ni garantiza ningún pago o transacción. Cualquier acuerdo comercial, entrega, cobro o disputa es responsabilidad exclusiva de las partes involucradas.

5. PEDIDOS Y WHATSAPP
Los pedidos generados a través de la app se envían mediante WhatsApp al número registrado por el negocio. YapiVenta no garantiza la entrega, disponibilidad del producto ni la respuesta oportuna del vendedor.

6. MENORES DE EDAD
YapiVenta no está dirigida a menores de 18 años. Si eres menor de edad, necesitas la autorización expresa de tu padre, madre o tutor legal para usar la plataforma.

7. COOKIES Y RASTREO
La app puede usar identificadores de dispositivo y servicios de análisis (Firebase Analytics) para mejorar la experiencia del usuario. No usamos cookies de rastreo publicitario de terceros.

8. DISPONIBILIDAD DEL SERVICIO
YapiVenta no garantiza disponibilidad continua del servicio. Podemos realizar mantenimientos, actualizaciones o suspender el servicio temporalmente sin previo aviso.

9. SUSPENSIÓN Y CANCELACIÓN DE CUENTA
YapiVenta se reserva el derecho de suspender o eliminar cuentas que publiquen contenido ilegal o engañoso, incumplan estos términos o usen la plataforma para actividades fraudulentas, sin necesidad de previo aviso ni compensación.

10. CONTENIDO PROHIBIDO
Queda estrictamente prohibido publicar: productos ilegales, falsificados o peligrosos; contenido que viole derechos de autor o marcas registradas; material ofensivo o discriminatorio; productos cuya venta esté restringida por ley peruana.

11. PROPIEDAD INTELECTUAL
La marca YapiVenta, su diseño, logo, código fuente y todos sus elementos son propiedad exclusiva de sus creadores. Queda prohibido copiar, modificar, redistribuir o usar estos elementos con fines comerciales sin autorización expresa y por escrito.

12. LIMITACIÓN DE RESPONSABILIDAD
YapiVenta no se hace responsable por pérdidas económicas derivadas del uso de la plataforma, errores en precios o descripciones ingresados por el usuario, fallas en servicios de terceros (Firebase, Cloudinary, WhatsApp), ni por el comportamiento de compradores o vendedores.

13. LEGISLACIÓN APLICABLE
Estos términos se rigen por las leyes de la República del Perú. Cualquier controversia se someterá a los juzgados de la ciudad de Huánuco, Perú.

14. MODIFICACIONES DE LOS TÉRMINOS
YapiVenta puede actualizar estos términos en cualquier momento. El uso continuo de la plataforma después de los cambios implica su aceptación automática.

Al presionar 'ENTENDIDO Y ACEPTO', confirmas que tienes al menos 18 años o cuentas con autorización de tu tutor legal, y que has leído, entendido y aceptado en su totalidad estos Términos y Condiciones de Uso de YapiVenta.
''';
