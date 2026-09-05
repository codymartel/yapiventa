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
import 'features/negocio/presentation/screens/configuracion_negocio_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        // '/home' es a donde va todo el mundo una vez que el negocio
        // ya está configurado (o recién se terminó de configurar).
        // '/productos' es el listado de productos del negocio (todavía
        // placeholder — se migra en el próximo paso).
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/elegir-rubro': (context) => SeleccionNegocioScreen(
                onTipoSeleccionado: (rubro) {
                  Navigator.of(context).pushReplacementNamed(
                    '/configurar-negocio',
                    arguments: rubro,
                  );
                },
              ),
          '/home': (context) => const _HomePlaceholder(),
          '/productos': (context) => const ProductosScreen(),
        },
        // '/configurar-negocio' necesita el argumento `rubro`, así que
        // se arma aparte con onGenerateRoute en vez de en el mapa
        // `routes` de arriba (el mapa no permite leer `arguments`
        // fácilmente antes de construir la pantalla).
        onGenerateRoute: (settings) {
          if (settings.name == '/configurar-negocio') {
            final rubro = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => ConfiguracionNegocioProvider(rubro: rubro),
                child: ConfiguracionNegocioScreen(
                  rubro: rubro,
                  onFinalizar: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/home',
                      (route) => false,
                    );
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