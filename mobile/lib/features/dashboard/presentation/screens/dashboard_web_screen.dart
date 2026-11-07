import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/authenticated_shell.dart';
import '../../../auth/domain/politica_acceso.dart';
import '../../../negocio/catalogo_negocio_dependencies.dart';
import '../../../negocio/data/negocio_repository.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../../../negocio/domain/models/seleccion_plantilla_info.dart';
import '../../../negocio/presentation/providers/configuracion_negocio_provider.dart';
import '../../../negocio/presentation/widgets/seleccion_negocio_content.dart';
import '../../../negocio/presentation/widgets/seleccion_plantilla_flow.dart';
import '../../../negocio/seleccion_plantilla_dependencies.dart';
import '../../../productos/presentation/widgets/productos_flow.dart';
import '../../../productos/presentation/widgets/productos_contextual_panel.dart';
import '../../../pedidos/pedidos_dependencies.dart';
import '../../../pedidos/presentation/widgets/pedidos_contextual_panel.dart';
import '../../../pedidos/presentation/widgets/pedidos_flow.dart';
import '../../../productos/productos_dependencies.dart';
import '../providers/dashboard_provider.dart';
import '../state/dashboard_ui_state.dart';
import '../widgets/dashboard_attention_panel.dart';
import '../widgets/configuracion_contextual_panel.dart';
import '../widgets/rubro_contextual_panel.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_top_bar.dart';
import '../widgets/plantilla_contextual_panel.dart';
import 'abrir_tienda_publica.dart';
import 'dashboard_contenido_inicio.dart';
import 'rutas_inicio_dashboard.dart';
import 'seccion_dashboard.dart';

export 'abrir_tienda_publica.dart' show AbrirUrlDashboard;

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

  /// Se arma sola (producción) si no se pasa: solo se crea al abrir Pedidos.
  final PedidosDependencies? pedidosDependencies;
  final CatalogoNegocioDependencies? catalogoDependencies;
  final SeleccionPlantillaDependencies? seleccionPlantillaDependencies;

  /// Menú visible. Por defecto, la versión 1 (`destinosPanelV1`).
  final Set<DashboardDestination> destinosVisibles;

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
    this.pedidosDependencies,
    this.catalogoDependencies,
    this.seleccionPlantillaDependencies,
    this.destinosVisibles = destinosPanelV1,
  });

  @override
  State<DashboardWebScreen> createState() => _DashboardWebScreenState();
}

class _DashboardWebScreenState extends State<DashboardWebScreen> {
  /// Sección activa. Una sola variable en vez de una bandera por sección:
  /// así nunca quedan dos abiertas a la vez.
  SeccionDashboard _seccion = SeccionDashboard.inicio;

  bool get _rubroAbierta => _seccion == SeccionDashboard.rubro;
  bool get _configuracionAbierta => _seccion == SeccionDashboard.configuracion;
  bool get _productosAbierta => _seccion == SeccionDashboard.productos;
  bool get _plantillaAbierta => _seccion == SeccionDashboard.plantilla;
  bool get _pedidosAbierta => _seccion == SeccionDashboard.pedidos;

  /// Se marca en la primera visita para montar la rama Productos de forma
  /// perezosa: al entrar al dashboard no existe ninguna instancia del flow.
  bool _productosVisitada = false;

  /// Se marca en la primera visita permitida a Plantilla para montar su rama
  /// (y, con ella, el provider y la carga inicial) una sola vez. Mientras el
  /// usuario esté en Plantilla, la rama se mantiene viva vía Offstage.
  bool _plantillaVisitada = false;

  /// Se arma una sola vez, al abrir Pedidos por primera vez.
  PedidosDependencies? _pedidosDependencias;

  /// Configuración se abrió desde el formulario de un producto: muestra
  /// «Guardar y volver al producto».
  bool _vieneDeProducto = false;

  /// Cada +1 le dice a Productos que reabra el formulario que quedó a medias.
  final ValueNotifier<int> _volverAlProducto = ValueNotifier<int>(0);
  late String _rubroContextual;
  ConfiguracionNegocioProvider? _providerConfiguracion;
  late final NavigatorObserver _observadorInterno;
  late final ValueNotifier<ProgresoConfiguracion> _progresoNotifier;
  late final RutasInicioDashboard _rutas;

  @override
  void initState() {
    super.initState();
    _rubroContextual = _rubroCompatible(widget.progreso.catalogo.rubro);
    _progresoNotifier = ValueNotifier<ProgresoConfiguracion>(widget.progreso);
    _rutas = RutasInicioDashboard(
      uid: widget.uid,
      negocioId: widget.negocioId,
      progreso: _progresoNotifier,
      rubroActual: () => widget.progreso.catalogo.rubro,
      providerConfiguracion: () => _providerConfiguracion,
      vieneDeProducto: () => _vieneDeProducto,
      alVolverAlProducto: _volverAlProductoDesdeConfiguracion,
      recargarProgreso: widget.recargarProgreso,
      alCambiarRubro: _cambiarRubroContextual,
      alAbrirEtapa: _abrirEtapa,
    );
    _observadorInterno = ObservadorRutasInternas(() {
      if (!mounted || (!_rubroAbierta && !_configuracionAbierta)) return;
      setState(() => _seccion = SeccionDashboard.inicio);
    });
  }

  @override
  void didUpdateWidget(covariant DashboardWebScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.progreso, widget.progreso)) {
      _progresoNotifier.value = widget.progreso;
    }
    if (oldWidget.progreso.catalogo.rubro != widget.progreso.catalogo.rubro) {
      _providerConfiguracion?.dispose();
      _providerConfiguracion = null;
      if (!_rubroAbierta) {
        _rubroContextual = _rubroCompatible(widget.progreso.catalogo.rubro);
      }
    }
  }

  @override
  void dispose() {
    _providerConfiguracion?.dispose();
    _volverAlProducto.dispose();
    _progresoNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardProvider>().state;
    return AuthenticatedShell(
      ayudaSeccionId: _seccion.ayudaId,
      navigationBuilder: (_, closeNavigation) => DashboardSidebar(
        destinoActivo: _seccion.destinoActivo,
        onSeleccionar: (destino) {
          closeNavigation?.call();
          _seleccionarDestino(context, destino);
        },
        estaHabilitado: _destinoHabilitado,
        destinosVisibles: widget.destinosVisibles,
      ),
      topBarBuilder: (context, openNavigation, openHelp) => DashboardTopBar(
        nombreNegocio: _nombreNegocio(state),
        onElegirPlantilla: () => _abrirPlantilla(context, widget.progreso),
        onVerTienda: () => _verTiendaWeb(context),
        onAbrirMenu: openNavigation,
        onAbrirAyuda: openHelp,
        email: widget.email,
        onCerrarSesion: widget.onCerrarSesion,
      ),
      contextualPanel: _pedidosAbierta
          ? const PedidosContextualPanel()
          : _configuracionAbierta && _providerConfiguracion != null
          ? ConfiguracionContextualPanel(provider: _providerConfiguracion!)
          : _plantillaAbierta
          ? const PlantillaContextualPanel()
          : _productosAbierta
          ? const ProductosContextualPanel()
          : _rubroAbierta
          ? RubroContextualPanel(rubro: _rubroContextual)
          : DashboardAttentionPanel(
              items: state.necesitanAtencion,
              productos: state.productosDestacados,
            ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _productosAbierta || _plantillaAbierta || _pedidosAbierta,
            child: Navigator(
              key: DashboardWebScreen.navegadorInicioClave,
              observers: [_observadorInterno],
              onGenerateInitialRoutes: (navigator, inicial) => [
                _rutas.crearInicio(RouteSettings(name: inicial)),
              ],
              onGenerateRoute: _rutas.crear,
            ),
          ),
          if (_productosVisitada)
            Offstage(
              offstage: !_productosAbierta,
              child: _crearRamaProductos(),
            ),
          if (_plantillaVisitada)
            Offstage(
              offstage: !_plantillaAbierta,
              child: _crearRamaPlantilla(),
            ),
          // Pedidos no se deja viva por detrás: al salir se cierran sus
          // listeners (ahorra lecturas) y al volver se abre de nuevo.
          if (_pedidosAbierta) _crearRamaPedidos(),
        ],
      ),
    );
  }

  void _cambiarRubroContextual(String rubro) {
    if (!mounted || _rubroContextual == rubro) return;
    setState(() => _rubroContextual = rubro);
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
      _rubroContextual = _rubroCompatible(progreso.catalogo.rubro);
      _seccion = SeccionDashboard.rubro;
    });
    Navigator.of(rutaContexto).pushNamed(RutasAcceso.rubro);
  }

  String _rubroCompatible(String rubro) {
    if (rubro == 'Farmacia' || rubro == 'Ferretería') return 'Otros';
    return SeleccionNegocioContent.esRubroDisponible(rubro) ? rubro : 'Otros';
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
      _seccion = SeccionDashboard.configuracion;
    });
    DashboardWebScreen.navegadorInicioClave.currentState!.pushNamed(
      RutasAcceso.negocio,
    );
  }

  /// Desde el formulario de producto: Configuración → Catálogo → Unidades de
  /// venta, donde se crean las presentaciones propias.
  void _abrirUnidadesDeVenta() {
    if (!mounted) return;
    DashboardWebScreen.navegadorInicioClave.currentState?.popUntil(
      (ruta) => ruta.isFirst,
    );
    _vieneDeProducto = true;
    _abrirConfiguracion(context, widget.progreso);
    _providerConfiguracion
      ?..irAPaso(1)
      ..cambiarCatalogoPestana(1);
  }

  /// «Guardar y volver al producto»: cierra Configuración, abre Productos y le
  /// avisa que reabra el formulario que quedó a medias.
  void _volverAlProductoDesdeConfiguracion() {
    if (!mounted) return;
    DashboardWebScreen.navegadorInicioClave.currentState?.popUntil(
      (ruta) => ruta.isFirst,
    );
    setState(() {
      _vieneDeProducto = false;
      _seccion = SeccionDashboard.productos;
      _productosVisitada = true;
    });
    _volverAlProducto.value++;
  }

  void _abrirProductos(
    BuildContext rutaContexto,
    ProgresoConfiguracion progreso,
  ) {
    _vieneDeProducto = false;
    if (!PoliticaAcceso.permite(RutasAcceso.productos, progreso)) {
      _mostrarBloqueado(rutaContexto);
      return;
    }
    setState(() {
      _seccion = SeccionDashboard.productos;
      _productosVisitada = true;
    });
  }

  void _abrirPlantilla(BuildContext context, ProgresoConfiguracion progreso) {
    if (!PoliticaAcceso.permite(RutasAcceso.plantilla, progreso)) {
      _mostrarBloqueado(context);
      return;
    }
    setState(() {
      _seccion = SeccionDashboard.plantilla;
      _plantillaVisitada = true;
    });
  }

  void _abrirPedidos(BuildContext context) {
    final negocioId = widget.negocioId;
    if (negocioId == null || negocioId.trim().isEmpty) {
      mostrarAvisoDashboard(
        context,
        'No se encontró tu negocio. Vuelve a iniciar sesión.',
      );
      return;
    }
    setState(() => _seccion = SeccionDashboard.pedidos);
  }

  Widget _crearRamaPedidos() {
    _pedidosDependencias ??=
        widget.pedidosDependencies ?? PedidosDependencies.production();
    return PedidosFlow(
      negocioId: widget.negocioId!,
      dependencias: _pedidosDependencias!,
    );
  }

  Widget _crearRamaPlantilla() {
    return SeleccionPlantillaFlow(
      uid: widget.uid,
      rubro: widget.progreso.catalogo.rubro,
      seleccionInicial: SeleccionPlantillaInfo(
        slug: widget.progreso.slug,
        plantillaGuardada: widget.progreso.plantilla,
        provieneDeCampoOficial: widget.progreso.plantillaProvieneDeCampoOficial,
      ),
      dependencies: widget.seleccionPlantillaDependencies,
      onVolver: _volverDesdePlantilla,
      onCompletado: _completarPlantilla,
      recargarProgreso: widget.recargarProgreso,
      onVerTienda: (slug) => _abrirTiendaWeb(context, slug),
    );
  }

  void _volverDesdePlantilla() {
    if (!mounted) return;
    setState(() {
      _seccion = SeccionDashboard.productos;
      _productosVisitada = true;
    });
  }

  void _completarPlantilla() {
    if (!mounted) return;
    setState(() => _seccion = SeccionDashboard.inicio);
  }

  Widget _crearRamaProductos() {
    return ProductosFlow(
      uid: widget.uid,
      negocioId: widget.negocioId,
      catalogoInicial: widget.progreso.catalogo,
      onVolver: () {
        if (!mounted || !_productosAbierta) return;
        setState(() => _seccion = SeccionDashboard.inicio);
      },
      onElegirPlantilla: (_) => _abrirPlantilla(context, widget.progreso),
      onProgressChanged: widget.recargarProgreso,
      onAbrirCatalogo: _abrirUnidadesDeVenta,
      volverAlProducto: _volverAlProducto,
      productosDependencies: widget.productosDependencies,
      catalogoDependencies: widget.catalogoDependencies,
      mostrarPanelesLaterales: false,
    );
  }

  void _seleccionarDestino(BuildContext context, DashboardDestination destino) {
    if (!_destinoHabilitado(destino)) {
      _mostrarBloqueado(context);
      return;
    }
    switch (destino) {
      case DashboardDestination.inicio:
        if (_productosAbierta || _plantillaAbierta || _pedidosAbierta) {
          setState(() => _seccion = SeccionDashboard.inicio);
        }
        return;
      case DashboardDestination.productos:
        _abrirProductos(context, widget.progreso);
        return;
      case DashboardDestination.plantilla:
        _abrirPlantilla(context, widget.progreso);
        return;
      case DashboardDestination.pedidos:
        _abrirPedidos(context);
        return;
      case DashboardDestination.ventas:
      case DashboardDestination.quejas:
      case DashboardDestination.plan:
      case DashboardDestination.ayuda:
        // Escondidos en el menú (ver destinosPanelV1): no hay nada que abrir.
        return;
      case DashboardDestination.configuracion:
        _abrirConfiguracion(context, widget.progreso);
        return;
    }
  }

  Future<void> _verTiendaWeb(BuildContext context) async {
    await _abrirTiendaWeb(context, widget.progreso.slug);
  }

  Future<void> _abrirTiendaWeb(BuildContext context, String slug) {
    return abrirTiendaPublica(
      context,
      progreso: widget.progreso,
      slug: slug,
      abrirUrl: widget.abrirUrl,
      alBloquear: () => _mostrarBloqueado(context),
    );
  }

  bool _destinoHabilitado(DashboardDestination destino) {
    return switch (destino) {
      DashboardDestination.inicio => true,
      DashboardDestination.productos => PoliticaAcceso.permite(
        RutasAcceso.productos,
        widget.progreso,
      ),
      DashboardDestination.plantilla => PoliticaAcceso.permite(
        RutasAcceso.plantilla,
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
    mostrarAvisoDashboard(
      context,
      'Completa primero las etapas pendientes de configuración.',
    );
  }
}
