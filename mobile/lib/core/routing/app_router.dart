import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/verificacion_email_screen.dart';
import '../../features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import '../../features/negocio/presentation/screens/configuracion_negocio_screen.dart';
import '../../features/negocio/presentation/screens/seleccion_negocio_screen.dart';
import '../../features/home/presentation/screens/home_placeholder.dart';
import 'rutas.dart';

/// Rutas sin argumentos, para el mapa `routes` de MaterialApp.
final Map<String, WidgetBuilder> appRoutes = {
  Rutas.login: (context) => const LoginScreen(),
  Rutas.verificarCorreo: (context) => const VerificacionEmailScreen(),
  Rutas.elegirRubro: (context) => SeleccionNegocioScreen(
        onTipoSeleccionado: (rubro) {
          Navigator.of(context).pushReplacementNamed(
            Rutas.configurarNegocio,
            arguments: rubro,
          );
        },
      ),
  Rutas.home: (context) => const HomePlaceholder(),
};

/// `/configurar-negocio` necesita el rubro como argumento, así que se
/// arma aquí en vez de en el mapa de arriba.
Route<dynamic>? generarRuta(RouteSettings settings) {
  if (settings.name == Rutas.configurarNegocio) {
    final rubro = settings.arguments as String;
    return MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (_) => ConfiguracionNegocioProvider(rubro: rubro),
        child: ConfiguracionNegocioScreen(
          rubro: rubro,
          onFinalizar: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              Rutas.home,
              (route) => false,
            );
          },
        ),
      ),
    );
  }
  return null;
}
