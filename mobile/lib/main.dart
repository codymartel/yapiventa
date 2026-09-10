import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'features/productos/presentation/screens/productos_screen.dart';
import 'features/negocio/seleccion_plantilla_dependencies.dart';
import 'features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'features/negocio/presentation/providers/seleccion_plantilla_provider.dart';
import 'features/negocio/presentation/screens/seleccion_negocio_screen.dart';
import 'features/negocio/presentation/screens/seleccion_plantilla_screen.dart';
import 'features/negocio/presentation/screens/configuracion_negocio_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'YapiVenta',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        // ── RUTAS NOMBRADAS ─────────────────────────────────────────
        // FLUJO DEL USUARIO NUEVO:
        //   verificación (login/verificar-correo)
        //   → '/elegir-rubro'   (selección de rubro)
        //   → '/configurar-negocio' (wizard de 4 pasos)
        //   → '/productos'           (gestión de productos)
        //   → '/elegir-plantilla'    (se elige DESPUÉS de los productos,
        //                            desde el botón del AppBar de Productos)
        // '/configurar-negocio' recibe el rubro elegido como argumento.
        // '/home' queda como placeholder temporal.
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/elegir-rubro': (context) => SeleccionNegocioScreen(
            onTipoSeleccionado: (rubro) {
              // Conserva Rubro en el historial mientras se configura el
              // negocio, para que el usuario pueda cambiar su eleccion.
              Navigator.of(
                context,
              ).pushNamed('/configurar-negocio', arguments: rubro);
            },
          ),
          '/elegir-plantilla': (context) {
            final argumentos = ModalRoute.of(context)?.settings.arguments;
            final mapa = argumentos is Map<String, dynamic>
                ? argumentos
                : const <String, dynamic>{};
            final rubro = argumentos is String
                ? argumentos
                : (mapa['rubro'] as String? ?? '');
            final uid = context.read<AuthProvider>().usuarioActual?.uid ?? '';
            return ChangeNotifierProvider(
              create: (_) => _crearSeleccionPlantillaProvider(uid),
              child: SeleccionPlantillaScreen(
                rubro: rubro,
                onPlantillaSeleccionada: (plantilla) {
                  if (context.mounted) Navigator.of(context).pop(plantilla);
                },
              ),
            );
          },
          '/home': (context) {
            if (!kIsWeb) return const _HomePlaceholder();

            final uid = context.read<AuthProvider>().usuarioActual?.uid ?? '';
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => DashboardProvider()),
                // Precarga una vez slug y plantilla antes de cualquier clic.
                ChangeNotifierProvider(
                  create: (_) => _crearSeleccionPlantillaProvider(uid),
                ),
              ],
              child: const DashboardWebScreen(),
            );
          },
          '/productos': (context) => const ProductosScreen(),
        },
        // '/configurar-negocio' necesita el argumento `rubro`, así que
        // se arma aparte con onGenerateRoute en vez de en el mapa
        // `routes` de arriba (el mapa no permite leer `arguments`
        // fácilmente antes de construir la pantalla).
        onGenerateRoute: (settings) {
          if (settings.name == '/configurar-negocio') {
            final argumentos = settings.arguments;
            final configuracionInicial = argumentos is Map<String, dynamic>
                ? argumentos['configuracionInicial'] as Map<String, dynamic>?
                : null;
            final rubro = argumentos is Map<String, dynamic>
                ? argumentos['rubro'] as String
                : argumentos as String;
            return MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => ConfiguracionNegocioProvider(
                  rubro: rubro,
                  configuracionInicial: configuracionInicial,
                ),
                child: ConfiguracionNegocioScreen(
                  rubro: rubro,
                  onVolver: () => Navigator.of(context).pop(),
                  onFinalizar: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/productos', (route) => false);
                  },
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}

SeleccionPlantillaProvider _crearSeleccionPlantillaProvider(String uid) {
  final dependencies = SeleccionPlantillaDependencies.production();
  return SeleccionPlantillaProvider(
    uid: uid,
    obtenerSeleccionPlantilla: dependencies.obtenerSeleccionPlantilla,
    guardarPlantillaWeb: dependencies.guardarPlantillaWeb,
  )..cargar();
}

/// Placeholder temporal de Home — se reemplaza cuando migres
/// home_screen.dart de verdad. Vive aquí (no en verificacion_email_screen.dart
/// ni en register_screen.dart) para que TODOS los caminos que llegan a
/// "Home" usen exactamente la misma pantalla, definida una sola vez.
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
