import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/authenticated_shell.dart';
import '../../../auth/domain/politica_acceso.dart';
import '../../../caja/caja_dependencies.dart';
import '../../../caja/presentation/widgets/caja_contextual_panel.dart';
import '../../../negocio/catalogo_negocio_dependencies.dart';
import '../../../negocio/data/negocio_repository.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../../../negocio/domain/models/seleccion_plantilla_info.dart';
import '../../../negocio/presentation/widgets/seleccion_plantilla_flow.dart';
import '../../../negocio/seleccion_plantilla_dependencies.dart';
import '../../../productos/presentation/widgets/productos_flow.dart';
import '../../../productos/presentation/widgets/productos_contextual_panel.dart';
import '../../../pedidos/pedidos_dependencies.dart';
import '../../../pedidos/presentation/widgets/pedidos_contextual_panel.dart';
import '../../../pedidos/presentation/widgets/pedidos_flow.dart';
import '../../../productos/productos_dependencies.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_attention_panel.dart';
import '../widgets/configuracion_contextual_panel.dart';
import '../widgets/rubro_contextual_panel.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_top_bar.dart';
import '../widgets/plantilla_contextual_panel.dart';
import 'abrir_tienda_publica.dart';
import 'dashboard_contenido_inicio.dart';
import 'negocio_dashboard.dart';
import 'rama_caja_dashboard.dart';
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
  final VoidCallback? onEliminarCuenta;
  final ProductosDependencies? productosDependencies;

  final PedidosDependencies? pedidosDependencies;
  final CajaDependencies? cajaDependencies;
  final CatalogoNegocioDependencies? catalogoDependencies;
  final SeleccionPlantillaDependencies? seleccionPlantillaDependencies;

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
    this.onEliminarCuenta,
    this.productosDependencies,
    this.pedidosDependencies,
    this.cajaDependencies,
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
  bool get _cajaAbierta => _seccion == SeccionDashboard.caja;

  /// La sección abierta tiene su propia rama (no es el navegador de Inicio).
  bool get _ramaPropia =>
      _productosAbierta || _plantillaAbierta || _pedidosAbierta || _cajaAbierta;

  /// Se marca en la primera visita para montar la rama Productos de forma
  /// perezosa: al entrar al dashboard no existe ninguna instancia del flow.
  bool _productosVisitada = false;

  /// Se marca en la primera visita permitida a Plantilla para montar su rama
  /// (y, con ella, el provider y la carga inicial) una sola vez. Mientras el
  /// usuario esté en Plantilla, la rama se mantiene viva vía Offstage.
  bool _plantillaVisitada = false;

  /// Se arma una sola vez, al abrir Pedidos por primera vez.
  PedidosDependencies? _pedidosDependencias;

  late final NegocioDashboard _negocio = NegocioDashboard(
    negocioId: widget.negocioId,
    navegador: DashboardWebScreen.navegadorInicioClave,
  );
  late String _rubroContextual;
  late final NavigatorObserver _observadorInterno;
  late final ValueNotifier<ProgresoConfiguracion> _progresoNotifier;
  late final RutasInicioDashboard _rutas;

  @override
  void initState() {
    super.initState();
    _rubroContextual = rubroCompatibleDashboard(widget.progreso.catalogo.rubro);
    _progresoNotifier = ValueNotifier<ProgresoConfiguracion>(widget.progreso);
    _rutas = RutasInicioDashboard(
      uid: widget.uid,
      negocioId: widget.negocioId,
      progreso: _progresoNotifier,
      rubroActual: () => widget.progreso.catalogo.rubro,
      providerConfiguracion: () => _negocio.provider,
      vieneDeProducto: () => _negocio.vieneDeProducto,
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
      _negocio.olvidarProvider();
      if (!_rubroAbierta) {
        _rubroContextual = rubroCompatibleDashboard(
          widget.progreso.catalogo.rubro,
        );
      }
    }
  }

  @override
  void dispose() {
    _negocio.dispose();
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
        estaHabilitado: (d) => destinoHabilitado(d, widget.progreso),
        destinosVisibles: widget.destinosVisibles,
      ),
      topBarBuilder: (context, openNavigation, openHelp) => DashboardTopBar(
        nombreNegocio: nombreNegocioDashboard(widget.progreso, state),
        onElegirPlantilla: () => _abrirPlantilla(context, widget.progreso),
        onVerTienda: () => _verTiendaWeb(context),
        onAbrirMenu: openNavigation,
        onAbrirAyuda: openHelp,
        email: widget.email,
        onCerrarSesion: widget.onCerrarSesion,
        onEliminarCuenta: widget.onEliminarCuenta,
      ),
      contextualPanel: _pedidosAbierta
          ? const PedidosContextualPanel()
          : _cajaAbierta
          ? const CajaContextualPanel()
          : _configuracionAbierta && _negocio.provider != null
          ? ConfiguracionContextualPanel(provider: _negocio.provider!)
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
            offstage: _ramaPropia,
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
          // Pedidos y Caja no se dejan vivas por detrás: al salir se cierran
          // sus listeners (ahorra lecturas) y al volver se abren de nuevo.
          if (_pedidosAbierta) _crearRamaPedidos(),
          if (_cajaAbierta)
            RamaCajaDashboard(
              negocioId: widget.negocioId!,
              progreso: widget.progreso,
              dependencias: widget.cajaDependencies,
            ),
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
      _rubroContextual = rubroCompatibleDashboard(progreso.catalogo.rubro);
      _seccion = SeccionDashboard.rubro;
    });
    Navigator.of(rutaContexto).pushNamed(RutasAcceso.rubro);
  }

  void _abrirConfiguracion(
    BuildContext rutaContexto,
    ProgresoConfiguracion progreso,
  ) {
    if (!NegocioDashboard.permitida(progreso)) {
      _mostrarBloqueado(rutaContexto);
      return;
    }
    setState(() => _seccion = SeccionDashboard.configuracion);
    _negocio.abrir(progreso, rutaContexto.read<NegocioRepository>());
  }

  /// Desde el formulario de producto: Configuración → Catálogo → Unidades de
  /// venta, donde se crean las presentaciones propias.
  void _abrirUnidadesDeVenta() {
    if (!mounted) return;
    _negocio
      ..cerrarRutas()
      ..vieneDeProducto = true;
    _abrirConfiguracion(context, widget.progreso);
    _negocio.irAUnidadesDeVenta();
  }

  /// «Guardar y volver al producto»: cierra Configuración, abre Productos y le
  /// avisa que reabra el formulario que quedó a medias.
  void _volverAlProductoDesdeConfiguracion() {
    if (!mounted) return;
    _negocio.cerrarRutas();
    setState(() {
      _negocio.vieneDeProducto = false;
      _seccion = SeccionDashboard.productos;
      _productosVisitada = true;
    });
    _negocio.volverAlProducto.value++;
  }

  void _abrirProductos(
    BuildContext rutaContexto,
    ProgresoConfiguracion progreso,
  ) {
    _negocio.vieneDeProducto = false;
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

  /// Abre Pedidos o Caja: las dos necesitan el negocio.
  void _abrirVentas(BuildContext context, SeccionDashboard seccion) {
    final negocioId = widget.negocioId;
    if (negocioId == null || negocioId.trim().isEmpty) {
      mostrarAvisoDashboard(
        context,
        'No se encontró tu negocio. Vuelve a iniciar sesión.',
      );
      return;
    }
    setState(() => _seccion = seccion);
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
      volverAlProducto: _negocio.volverAlProducto,
      productosDependencies: widget.productosDependencies,
      catalogoDependencies: widget.catalogoDependencies,
      mostrarPanelesLaterales: false,
    );
  }

  void _seleccionarDestino(BuildContext context, DashboardDestination destino) {
    if (!destinoHabilitado(destino, widget.progreso)) {
      _mostrarBloqueado(context);
      return;
    }
    switch (destino) {
      case DashboardDestination.inicio:
        if (_ramaPropia) {
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
        _abrirVentas(context, SeccionDashboard.pedidos);
        return;
      case DashboardDestination.ventas:
        _abrirVentas(context, SeccionDashboard.caja);
        return;
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

  void _mostrarBloqueado(BuildContext context) {
    mostrarAvisoDashboard(
      context,
      'Completa primero las etapas pendientes de configuración.',
    );
  }
}
