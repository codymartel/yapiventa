import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/productos/presentation/screens/productos_screen.dart';
import 'features/negocio/presentation/providers/configuracion_negocio_provider.dart';
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
        // '/' y '/registro' no reciben datos.
        // '/elegir-rubro' es a donde AuthProvider manda cuando
        // setupComplete == false (usuario nuevo).
        // '/configurar-negocio' recibe el rubro elegido como argumento
        // — ver cómo se navega hacia ella en seleccion_negocio_screen.dart.
        // '/home' queda como placeholder temporal.
        // '/productos' es el listado de productos del negocio y recibe al
        // usuario al terminar la configuración inicial.
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/elegir-rubro': (context) => SeleccionNegocioScreen(
            onTipoSeleccionado: (rubro) {
              // Conserva Rubro en el historial mientras se configura el
              // negocio, para que el usuario pueda cambiar su eleccion.
              Navigator.of(context).pushNamed('/elegir-plantilla', arguments: rubro);
            },
          ),
          '/elegir-plantilla': (context) {
            final argumentos = ModalRoute.of(context)?.settings.arguments;
            final rubro = argumentos is String ? argumentos : '';
            return SeleccionPlantillaScreen(
              rubro: rubro,
              onPlantillaSeleccionada: (plantilla) {
                Navigator.of(context).pushNamed('/configurar-negocio', arguments: {
                  'rubro': rubro,
                  'plantilla': plantilla,
                });
              },
            );
          },
          '/home': (context) => const _HomePlaceholder(),
          '/productos': (context) => const ProductosScreen(),
        },
        // '/configurar-negocio' necesita argumentos (rubro y plantilla
        // opcional), así que se arma aparte con onGenerateRoute en vez de
        // en el mapa `routes` de arriba (el mapa no permite leer
        // `arguments` fácilmente antes de construir la pantalla).
        onGenerateRoute: (settings) {
          if (settings.name == '/configurar-negocio') {
            final argumentos = settings.arguments;
            final configuracionInicial = argumentos is Map<String, dynamic>
                ? argumentos['configuracionInicial'] as Map<String, dynamic>?
                : null;
            final rubro = argumentos is Map<String, dynamic>
                ? argumentos['rubro'] as String
                : argumentos as String;
            final plantilla = argumentos is Map<String, dynamic>
                ? argumentos['plantilla'] as String?
                : null;
            return MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => ConfiguracionNegocioProvider(
                  rubro: rubro,
                  plantilla: plantilla,
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
