import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/user_repository.dart';
import 'features/auth/domain/politica_acceso.dart';
import 'features/auth/presentation/providers/acceso_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/verificacion_email_screen.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/dashboard/presentation/screens/dashboard_web_screen.dart';
import 'features/negocio/data/negocio_repository.dart';
import 'features/negocio/domain/models/progreso_configuracion.dart';
import 'features/negocio/domain/models/seleccion_plantilla_info.dart';
import 'features/negocio/presentation/providers/configuracion_negocio_provider.dart';
import 'features/negocio/presentation/providers/seleccion_plantilla_provider.dart';
import 'features/negocio/presentation/screens/configuracion_negocio_screen.dart';
import 'features/negocio/presentation/screens/seleccion_negocio_screen.dart';
import 'features/negocio/presentation/screens/seleccion_plantilla_screen.dart';
import 'features/negocio/seleccion_plantilla_dependencies.dart';
import 'features/productos/presentation/screens/productos_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final AuthRepository? authRepository;
  final UserRepository? userRepository;
  final NegocioRepository? negocioRepository;
  final String? initialRoute;

  const MyApp({
    super.key,
    this.authRepository,
    this.userRepository,
    this.negocioRepository,
    this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    final authRepository = this.authRepository ?? AuthRepository();
    final userRepository = this.userRepository ?? UserRepository();
    final negocioRepository = this.negocioRepository ?? NegocioRepository();
    return MultiProvider(
      providers: [
        Provider<NegocioRepository>.value(value: negocioRepository),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            repository: authRepository,
            userRepository: userRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AccesoProvider(
            authRepository: authRepository,
            authProvider: context.read<AuthProvider>(),
            userRepository: userRepository,
            progresoRepository: negocioRepository,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'YapiVenta',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        initialRoute: initialRoute,
        onGenerateInitialRoutes: (rutaInicial) => [
          _crearRuta(RouteSettings(name: rutaInicial)),
        ],
        onGenerateRoute: _crearRuta,
      ),
    );
  }
}

Route<dynamic> _crearRuta(RouteSettings settings) {
  final ruta = switch (settings.name) {
    RutasAcceso.verificacion => RutasAcceso.verificacion,
    RutasAcceso.dashboard => RutasAcceso.dashboard,
    RutasAcceso.rubro => RutasAcceso.rubro,
    RutasAcceso.negocio => RutasAcceso.negocio,
    RutasAcceso.productos => RutasAcceso.productos,
    RutasAcceso.plantilla => RutasAcceso.plantilla,
    _ => RutasAcceso.acceso,
  };
  return MaterialPageRoute(
    settings: RouteSettings(name: ruta, arguments: settings.arguments),
    builder: (context) => _RutaConAcceso(ruta: ruta),
  );
}

class _RutaConAcceso extends StatelessWidget {
  final String ruta;

  const _RutaConAcceso({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final acceso = context.watch<AccesoProvider>();
    switch (acceso.estado) {
      case EstadoAcceso.cargandoSesion:
      case EstadoAcceso.cargandoProgreso:
        return const _PantallaCargaAcceso();
      case EstadoAcceso.sinSesion:
        return ruta == RutasAcceso.acceso
            ? const LoginScreen()
            : const _RedireccionRuta(RutasAcceso.acceso);
      case EstadoAcceso.correoNoVerificado:
        return ruta == RutasAcceso.verificacion
            ? const VerificacionEmailScreen()
            : const _RedireccionRuta(RutasAcceso.verificacion);
      case EstadoAcceso.error:
        return _PantallaErrorAcceso(mensaje: acceso.errorMessage);
      case EstadoAcceso.listo:
        final progreso = acceso.progreso!;
        if (ruta == RutasAcceso.acceso || ruta == RutasAcceso.verificacion) {
          return const _RedireccionRuta(RutasAcceso.dashboard);
        }
        if (!PoliticaAcceso.permite(ruta, progreso)) {
          return const _RedireccionRuta(RutasAcceso.dashboard);
        }
        return _construirRutaAutorizada(context, acceso, progreso);
    }
  }

  Widget _construirRutaAutorizada(
    BuildContext context,
    AccesoProvider acceso,
    ProgresoConfiguracion progreso,
  ) {
    switch (ruta) {
      case RutasAcceso.dashboard:
        return ChangeNotifierProvider(
          create: (_) => DashboardProvider(),
          child: DashboardWebScreen(
            progreso: progreso,
            email: acceso.email ?? '',
            onAbrirEtapa: (etapa) =>
                Navigator.of(context).pushNamed(PoliticaAcceso.rutaDe(etapa)),
            onCerrarSesion: () => context.read<AuthProvider>().cerrarSesion(),
          ),
        );
      case RutasAcceso.rubro:
        return SeleccionNegocioScreen(
          rubroInicial: progreso.catalogo.rubro,
          onVolverDashboard: () => _irAlDashboard(context),
          onTipoSeleccionado: (rubro) async {
            final guardado = await acceso.guardarRubro(rubro);
            if (guardado && context.mounted) {
              Navigator.of(context).pushNamed(RutasAcceso.negocio);
            }
            return guardado;
          },
        );
      case RutasAcceso.negocio:
        return ChangeNotifierProvider(
          create: (_) => ConfiguracionNegocioProvider(
            rubro: progreso.catalogo.rubro,
            configuracionInicial: progreso.catalogo.configuracionInicial,
            repository: context.read<NegocioRepository>(),
          ),
          child: ConfiguracionNegocioScreen(
            uid: acceso.uid!,
            rubro: progreso.catalogo.rubro,
            onVolver: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                _irAlDashboard(context);
              }
            },
            onFinalizar: () async {
              await acceso.recargar();
              if (context.mounted) _irAlDashboard(context);
            },
          ),
        );
      case RutasAcceso.productos:
        return ProductosScreen(
          uid: acceso.uid!,
          catalogoInicial: progreso.catalogo,
          onProgressChanged: () => acceso.recargar(),
        );
      case RutasAcceso.plantilla:
        return ChangeNotifierProvider(
          create: (_) => _crearSeleccionPlantillaProvider(
            acceso.uid!,
            progreso,
            context.read<NegocioRepository>(),
          ),
          child: SeleccionPlantillaScreen(
            rubro: progreso.catalogo.rubro,
            onPlantillaSeleccionada: (_) async {
              await acceso.recargar();
              if (context.mounted) _irAlDashboard(context);
            },
          ),
        );
      default:
        return const _RedireccionRuta(RutasAcceso.dashboard);
    }
  }

  void _irAlDashboard(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RutasAcceso.dashboard, (route) => false);
  }
}

SeleccionPlantillaProvider _crearSeleccionPlantillaProvider(
  String uid,
  ProgresoConfiguracion progreso,
  NegocioRepository repository,
) {
  final dependencies = SeleccionPlantillaDependencies.fromRepository(
    repository,
  );
  return SeleccionPlantillaProvider(
    uid: uid,
    obtenerSeleccionPlantilla: dependencies.obtenerSeleccionPlantilla,
    guardarPlantillaWeb: dependencies.guardarPlantillaWeb,
    seleccionInicial: SeleccionPlantillaInfo(
      slug: progreso.slug,
      plantillaGuardada: progreso.plantilla,
      provieneDeCampoOficial: progreso.plantillaProvieneDeCampoOficial,
    ),
  );
}

class _RedireccionRuta extends StatefulWidget {
  final String ruta;

  const _RedireccionRuta(this.ruta);

  @override
  State<_RedireccionRuta> createState() => _RedireccionRutaState();
}

class _RedireccionRutaState extends State<_RedireccionRuta> {
  bool _programada = false;

  @override
  Widget build(BuildContext context) {
    if (!_programada) {
      _programada = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(widget.ruta, (route) => false);
      });
    }
    return const _PantallaCargaAcceso();
  }
}

class _PantallaCargaAcceso extends StatelessWidget {
  const _PantallaCargaAcceso();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.fondo,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PantallaErrorAcceso extends StatelessWidget {
  final String? mensaje;

  const _PantallaErrorAcceso({this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 52),
                const SizedBox(height: 16),
                Text(
                  mensaje ?? 'No se pudo cargar tu configuración.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: context.read<AccesoProvider>().recargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: context.read<AuthProvider>().cerrarSesion,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
