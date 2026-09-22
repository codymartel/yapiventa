import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/authenticated_shell.dart';
import '../../../auth/domain/politica_acceso.dart';
import '../../../auth/presentation/providers/acceso_provider.dart';
import '../../../negocio/catalogo_negocio_dependencies.dart';
import '../../../negocio/data/negocio_repository.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../../../negocio/presentation/providers/configuracion_negocio_provider.dart';
import '../../../negocio/presentation/widgets/configuracion_negocio_flow.dart';
import '../../../negocio/presentation/widgets/seleccion_negocio_flow.dart';
import '../../../productos/presentation/widgets/productos_flow.dart';
import '../../../productos/productos_dependencies.dart';
import '../providers/dashboard_provider.dart';
import '../state/dashboard_ui_state.dart';
import '../widgets/dashboard_attention_panel.dart';
import '../widgets/rubro_contextual_panel.dart';
import '../widgets/dashboard_home_content.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_top_bar.dart';

typedef AbrirUrlDashboard =
    Future<bool> Function(Uri url, {String? webOnlyWindowName});

class DashboardWebScreen extends StatefulWidget {
  static final GlobalKey<NavigatorState> navegadorInicioClave =
      GlobalKey<NavigatorState>();

  final AbrirUrlDashboard? abrirUrl;
  final ProgresoConfiguracion progreso;
  final String email;
  final String uid;
  final String? negocioId;
  final Future<void> Function()? recargarProgreso;
  final ValueChanged<EtapaConfiguracion> onAbrirEtapa;
  final VoidCallback onCerrarSesion;
  final ProductosDependencies? productosDependencies;
  final CatalogoNegocioDependencies? catalogoDependencies;

  const DashboardWebScreen({
    super.key,
    this.abrirUrl,
    required this.progreso,
    required this.email,
    required this.uid,
    this.negocioId,
    this.recargarProgreso,
    required this.onAbrirEtapa,
    required this.onCerrarSesion,
    this.productosDependencies,
    this.catalogoDependencies,
  });

  @override
  State<DashboardWebScreen> createState() => _DashboardWebScreenState();
}

class _DashboardWebScreenState extends State<DashboardWebScreen> {
  bool _rubroAbierta = false;
  bool _configuracionAbierta = false;
  bool _productosAbierta = false;

  /// Se marca en la primera visita para montar la rama Productos de forma
  /// perezosa: al entrar al dashboard no existe ninguna instancia del flow.
  bool _productosVisitada = false;
  ConfiguracionNegocioProvider? _providerConfiguracion;
  late final NavigatorObserver _observadorInterno;
  late final ValueNotifier<ProgresoConfiguracion> _progresoNotifier;

  @override
  void initState() {
    super.initState();
    _progresoNotifier = ValueNotifier<ProgresoConfiguracion>(widget.progreso);
    _observadorInterno = _ObservadorRutasInternas(() {
      if (!mounted || (!_rubroAbierta && !_configuracionAbierta)) return;
      setState(() {
        _rubroAbierta = false;
        _configuracionAbierta = false;
      });
    });
  }

  @override
  void didUpdateWidget(covariant DashboardWebScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.progreso, widget.progreso)) {
      _progresoNotifier.value = widget.progreso;
    }
  }

  @override
  void dispose() {
    _providerConfiguracion?.dispose();
    _progresoNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardProvider>().state;
    return AuthenticatedShell(
      navigationBuilder: (_, closeNavigation) => DashboardSidebar(
        destinoActivo: _productosAbierta
            ? DashboardDestination.productos
            : _configuracionAbierta
            ? DashboardDestination.configuracion
            : DashboardDestination.inicio,
        onSeleccionar: (destino) {
          closeNavigation?.call();
          _seleccionarDestino(context, destino);
        },
        estaHabilitado: _destinoHabilitado,
      ),
      topBarBuilder: (_, openNavigation) => DashboardTopBar(
        nombreNegocio: _nombreNegocio(state),
        onElegirPlantilla: () => _elegirPlantilla(context),
        onVerTienda: () => _verTiendaWeb(context),
        onAbrirMenu: openNavigation,
        email: widget.email,
        onCerrarSesion: widget.onCerrarSesion,
      ),
      contextualPanel: _configuracionAbierta || _productosAbierta
          ? null
          : _rubroAbierta
          ? const RubroContextualPanel()
          : DashboardAttentionPanel(
              items: state.necesitanAtencion,
              productos: state.productosDestacados,
            ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _productosAbierta,
            child: Navigator(
              key: DashboardWebScreen.navegadorInicioClave,
              observers: [_observadorInterno],
              onGenerateInitialRoutes: (navigator, inicial) => [
                _crearRutaDeInicio(RouteSettings(name: inicial)),
              ],
              onGenerateRoute: _crearRutaInterna,
            ),
          ),
          if (_productosVisitada)
            Offstage(
              offstage: !_productosAbierta,
              child: _crearRamaProductos(),
            ),
        ],
      ),
    );
  }

  Route<dynamic> _crearRutaInterna(RouteSettings settings) {
    if (settings.name == RutasAcceso.rubro) {
      return _crearRutaDeRubro(settings);
    }
    if (settings.name == RutasAcceso.negocio &&
        _providerConfiguracion != null) {
      return _crearRutaDeConfiguracion(settings);
    }
    return _crearRutaDeInicio(settings);
  }

  Route<dynamic> _crearRutaDeConfiguracion(RouteSettings settings) {
    final provider = _providerConfiguracion!;
    return MaterialPageRoute<Object?>(
      settings: settings,
      builder: (rutaContexto) =>
          ChangeNotifierProvider<ConfiguracionNegocioProvider>.value(
            value: provider,
            child: ConfiguracionNegocioFlow(
              uid: widget.uid,
              negocioId: widget.negocioId,
              onVolver: () => _regresarAInicio(rutaContexto),
              onCompletado: () => _regresarAInicio(rutaContexto),
              onRecargarProgreso: widget.recargarProgreso == null
                  ? null
                  : (uid, negocioId) => widget.recargarProgreso!(),
            ),
          ),
    );
  }

  Route<dynamic> _crearRutaDeInicio(RouteSettings settings) {
    return MaterialPageRoute<Object?>(
      settings: settings,
      builder: (rutaContexto) => ValueListenableBuilder<ProgresoConfiguracion>(
        valueListenable: _progresoNotifier,
        builder: (rutaContexto, progreso, _) => _ContenidoInicio(
          progreso: progreso,
          onAbrirEtapa: (etapa) => _abrirEtapa(rutaContexto, progreso, etapa),
        ),
      ),
    );
  }

  Route<dynamic> _crearRutaDeRubro(RouteSettings settings) {
    return MaterialPageRoute<Object?>(
      settings: settings,
      builder: (rutaContexto) => SeleccionNegocioFlow(
        rubroInicial: widget.progreso.catalogo.rubro,
        onTipoSeleccionado: (rubro) async =>
            rutaContexto.read<AccesoProvider>().guardarRubro(rubro),
        onVolver: () => _regresarAInicio(rutaContexto),
        onCompletado: () => _regresarAInicio(rutaContexto),
      ),
    );
  }

  void _regresarAInicio(BuildContext context) {
    final navegador = Navigator.of(context);
    if (navegador.canPop()) {
      navegador.pop();
    }
  }

  void _abrirEtapa(
    BuildContext rutaContexto,
    ProgresoConfiguracion progreso,
    EtapaConfiguracion etapa,
  ) {
    if (etapa == EtapaConfiguracion.rubro) {
      _abrirRubro(rutaContexto, progreso);
      return;
    }
    if (etapa == EtapaConfiguracion.negocio) {
      _abrirConfiguracion(rutaContexto, progreso);
      return;
    }
    if (etapa == EtapaConfiguracion.productos) {
      _abrirProductos(rutaContexto, progreso);
      return;
    }
    widget.onAbrirEtapa(etapa);
  }

  void _abrirRubro(BuildContext rutaContexto, ProgresoConfiguracion progreso) {
    if (!PoliticaAcceso.permite(RutasAcceso.rubro, progreso)) {
      _mostrarBloqueado(rutaContexto);
      return;
    }
    setState(() {
      _productosAbierta = false;
      _rubroAbierta = true;
      _configuracionAbierta = false;
    });
    Navigator.of(rutaContexto).pushNamed(RutasAcceso.rubro);
  }

  void _abrirConfiguracion(
    BuildContext rutaContexto,
    ProgresoConfiguracion progreso,
  ) {
    if (!PoliticaAcceso.permite(RutasAcceso.negocio, progreso)) {
      _mostrarBloqueado(rutaContexto);
      return;
    }
    _providerConfiguracion ??= ConfiguracionNegocioProvider(
      rubro: progreso.catalogo.rubro,
      negocioId: widget.negocioId,
      configuracionInicial: progreso.catalogo.configuracionInicial,
      repository: rutaContexto.read<NegocioRepository>(),
    );
    setState(() {
      _productosAbierta = false;
      _configuracionAbierta = true;
      _rubroAbierta = false;
    });
    DashboardWebScreen.navegadorInicioClave.currentState!.pushNamed(
      RutasAcceso.negocio,
    );
  }

  void _abrirProductos(
    BuildContext rutaContexto,
    ProgresoConfiguracion progreso,
  ) {
    if (!PoliticaAcceso.permite(RutasAcceso.productos, progreso)) {
      _mostrarBloqueado(rutaContexto);
      return;
    }
    setState(() {
      _productosAbierta = true;
      _configuracionAbierta = false;
      _rubroAbierta = false;
      _productosVisitada = true;
    });
  }

  Widget _crearRamaProductos() {
    return ProductosFlow(
      uid: widget.uid,
      negocioId: widget.negocioId,
      catalogoInicial: widget.progreso.catalogo,
      onVolver: () {
        if (!mounted) return;
        setState(() => _productosAbierta = false);
      },
      onElegirPlantilla: (_) =>
          widget.onAbrirEtapa(EtapaConfiguracion.plantilla),
      onProgressChanged: widget.recargarProgreso,
      productosDependencies: widget.productosDependencies,
      catalogoDependencies: widget.catalogoDependencies,
    );
  }

  void _seleccionarDestino(BuildContext context, DashboardDestination destino) {
    if (!_destinoHabilitado(destino)) {
      _mostrarBloqueado(context);
      return;
    }
    switch (destino) {
      case DashboardDestination.inicio:
        if (_productosAbierta) {
          setState(() => _productosAbierta = false);
        }
        return;
      case DashboardDestination.productos:
        _abrirProductos(context, widget.progreso);
        return;
      case DashboardDestination.pedidos:
        _mostrarProximamente(
          context,
          'Pedidos estará disponible próximamente.',
        );
        return;
      case DashboardDestination.ventas:
        _mostrarProximamente(context, 'Ventas estará disponible próximamente.');
        return;
      case DashboardDestination.quejas:
        _mostrarProximamente(
          context,
          'Reclamaciones estará disponible próximamente.',
        );
        return;
      case DashboardDestination.configuracion:
        _abrirConfiguracion(context, widget.progreso);
        return;
      case DashboardDestination.plan:
        _mostrarProximamente(context, 'Plan estará disponible próximamente.');
        return;
      case DashboardDestination.ayuda:
        _mostrarProximamente(context, 'Ayuda estará disponible próximamente.');
        return;
    }
  }

  Future<void> _elegirPlantilla(BuildContext context) async {
    if (!widget.progreso.productosCompletos) {
      _mostrarBloqueado(context);
      return;
    }
    widget.onAbrirEtapa(EtapaConfiguracion.plantilla);
  }

  Future<void> _verTiendaWeb(BuildContext context) async {
    if (!widget.progreso.completo) {
      _mostrarBloqueado(context);
      return;
    }
    if (widget.progreso.slug.isEmpty || widget.progreso.plantilla == null) {
      _mostrarProximamente(
        context,
        'Selecciona una plantilla para publicar tu tienda web.',
      );
      return;
    }

    final url = Uri.https(
      'yapiventa-tienda.web.app',
      '/${widget.progreso.slug}',
    );
    try {
      final lanzarUrl = widget.abrirUrl ?? launchUrl;
      final abierto = await lanzarUrl(url, webOnlyWindowName: '_blank');
      if (!abierto && context.mounted) {
        _mostrarProximamente(
          context,
          'El navegador no pudo abrir la tienda web.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error al abrir la tienda publica (${url.host}): '
        '${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _mostrarProximamente(
          context,
          'Ocurrió un error al abrir la tienda web. Intenta de nuevo.',
        );
      }
    }
  }

  void _mostrarProximamente(BuildContext context, String mensaje) {
    _mostrarAviso(context, mensaje);
  }

  bool _destinoHabilitado(DashboardDestination destino) {
    return switch (destino) {
      DashboardDestination.inicio => true,
      DashboardDestination.productos => PoliticaAcceso.permite(
        RutasAcceso.productos,
        widget.progreso,
      ),
      DashboardDestination.configuracion => PoliticaAcceso.permite(
        RutasAcceso.negocio,
        widget.progreso,
      ),
      _ => widget.progreso.completo,
    };
  }

  String _nombreNegocio(DashboardUiState state) {
    final nombre =
        widget.progreso.catalogo.configuracionInicial['nombreNegocio'];
    return nombre is String && nombre.trim().isNotEmpty
        ? nombre.trim()
        : state.nombreNegocio;
  }

  void _mostrarBloqueado(BuildContext context) {
    _mostrarAviso(
      context,
      'Completa primero las etapas pendientes de configuración.',
    );
  }
}

class _ObservadorRutasInternas extends NavigatorObserver {
  final VoidCallback _alRegresar;

  _ObservadorRutasInternas(this._alRegresar);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _alRegresar();
  }
}

void _mostrarAviso(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

class _ContenidoInicio extends StatelessWidget {
  final ProgresoConfiguracion progreso;
  final ValueChanged<EtapaConfiguracion> onAbrirEtapa;

  const _ContenidoInicio({required this.progreso, required this.onAbrirEtapa});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardProvider>().state;
    return DashboardHomeContent(
      state: state,
      progreso: progreso,
      onAbrirEtapa: onAbrirEtapa,
      onAgregarProducto: () => progreso.negocioCompleto
          ? onAbrirEtapa(EtapaConfiguracion.productos)
          : _mostrarAviso(
              context,
              'Completa primero las etapas pendientes de configuración.',
            ),
      onActualizarStock: () => _mostrarAviso(
        context,
        'El módulo de stock estará disponible próximamente.',
      ),
      onVerPedidos: () => _mostrarAviso(
        context,
        'El módulo de pedidos estará disponible próximamente.',
      ),
      onResponderQueja: () => _mostrarAviso(
        context,
        'El módulo de reclamaciones estará disponible próximamente.',
      ),
    );
  }
}
