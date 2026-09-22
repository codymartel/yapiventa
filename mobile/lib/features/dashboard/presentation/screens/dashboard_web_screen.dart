import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/authenticated_shell.dart';
import '../../../auth/domain/politica_acceso.dart';
import '../../../auth/presentation/providers/acceso_provider.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../../../negocio/presentation/widgets/seleccion_negocio_flow.dart';
import '../providers/dashboard_provider.dart';
import '../state/dashboard_ui_state.dart';
import '../widgets/dashboard_attention_panel.dart';
import '../widgets/dashboard_home_content.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_top_bar.dart';

typedef AbrirUrlDashboard =
    Future<bool> Function(Uri url, {String? webOnlyWindowName});

class DashboardWebScreen extends StatefulWidget {
  static const navegadorInicioClave = Key('dashboard-inner-navigator');

  final AbrirUrlDashboard? abrirUrl;
  final ProgresoConfiguracion progreso;
  final String email;
  final ValueChanged<EtapaConfiguracion> onAbrirEtapa;
  final VoidCallback onCerrarSesion;

  const DashboardWebScreen({
    super.key,
    this.abrirUrl,
    required this.progreso,
    required this.email,
    required this.onAbrirEtapa,
    required this.onCerrarSesion,
  });

  @override
  State<DashboardWebScreen> createState() => _DashboardWebScreenState();
}

class _DashboardWebScreenState extends State<DashboardWebScreen> {
  bool _rubroAbierta = false;
  late final NavigatorObserver _observadorInterno;

  @override
  void initState() {
    super.initState();
    _observadorInterno = _ObservadorRutasInternas(() {
      if (!mounted || !_rubroAbierta) return;
      setState(() => _rubroAbierta = false);
    });
  }

  @override
  void didUpdateWidget(covariant DashboardWebScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_claveProgreso(oldWidget.progreso) != _claveProgreso(widget.progreso)) {
      _rubroAbierta = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardProvider>().state;
    return AuthenticatedShell(
      navigationBuilder: (_, closeNavigation) => DashboardSidebar(
        destinoActivo: DashboardDestination.inicio,
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
      contextualPanel: _rubroAbierta
          ? null
          : DashboardAttentionPanel(
              items: state.necesitanAtencion,
              productos: state.productosDestacados,
            ),
      child: KeyedSubtree(
        key: DashboardWebScreen.navegadorInicioClave,
        child: Navigator(
          key: ValueKey(
            'dashboard-progreso-${_claveProgreso(widget.progreso)}',
          ),
          observers: [_observadorInterno],
          onGenerateInitialRoutes: (navigator, inicial) => [
            _crearRutaDeInicio(RouteSettings(name: inicial)),
          ],
          onGenerateRoute: _crearRutaInterna,
        ),
      ),
    );
  }

  Route<dynamic> _crearRutaInterna(RouteSettings settings) {
    if (settings.name == RutasAcceso.rubro) {
      return _crearRutaDeRubro(settings);
    }
    return _crearRutaDeInicio(settings);
  }

  Route<dynamic> _crearRutaDeInicio(RouteSettings settings) {
    return MaterialPageRoute<Object?>(
      settings: settings,
      builder: (rutaContexto) => _ContenidoInicio(
        progreso: widget.progreso,
        onAbrirEtapa: (etapa) => _abrirEtapa(rutaContexto, etapa),
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

  void _abrirEtapa(BuildContext rutaContexto, EtapaConfiguracion etapa) {
    if (etapa == EtapaConfiguracion.rubro) {
      _abrirRubro(rutaContexto);
      return;
    }
    widget.onAbrirEtapa(etapa);
  }

  void _abrirRubro(BuildContext rutaContexto) {
    if (!PoliticaAcceso.permite(RutasAcceso.rubro, widget.progreso)) {
      _mostrarBloqueado(rutaContexto);
      return;
    }
    setState(() => _rubroAbierta = true);
    Navigator.of(rutaContexto).pushNamed(RutasAcceso.rubro);
  }

  void _seleccionarDestino(BuildContext context, DashboardDestination destino) {
    if (!_destinoHabilitado(destino)) {
      _mostrarBloqueado(context);
      return;
    }
    switch (destino) {
      case DashboardDestination.inicio:
        return;
      case DashboardDestination.productos:
        widget.onAbrirEtapa(EtapaConfiguracion.productos);
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
        widget.onAbrirEtapa(EtapaConfiguracion.negocio);
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

  bool _destinoHabilitado(DashboardDestination destino) => switch (destino) {
    DashboardDestination.inicio => true,
    DashboardDestination.productos => widget.progreso.negocioCompleto,
    DashboardDestination.configuracion => widget.progreso.rubroCompleto,
    _ => widget.progreso.completo,
  };

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

String _claveProgreso(ProgresoConfiguracion p) =>
    '${p.catalogo.rubro}'
    '|${p.rubroCompleto}'
    '|${p.negocioCompleto}'
    '|${p.productosCompletos}'
    '|${p.plantillaCompleta}';

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
