import 'package:flutter/material.dart';

import '../services/ayuda_vista_service.dart';
import '../theme/app_colors.dart';

typedef AuthenticatedNavigationBuilder =
    Widget Function(BuildContext context, VoidCallback? closeNavigation);
typedef AuthenticatedTopBarBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback? openNavigation,
      VoidCallback? openHelp,
    );

/// Carcasa autenticada con un único [Scaffold] y distribución responsive.
///
/// El contenido central ocupa todo el ancho liberado: solo hay navegación
/// izquierda fija ([navigationWidth]) a partir de [anchoMinimoTresColumnas];
/// por debajo pasa a [Drawer]. No existe tercera columna fija.
///
/// La ayuda contextual ([contextualPanel]) vive como overlay desplegable,
/// cerrado por defecto:
///  - Ancho >= [overlayBottomSheetBreakpoint]: panel lateral derecho.
///  - Ancho < [overlayBottomSheetBreakpoint]: bottom sheet.
/// Se cierra al tocar fuera o con el botón X. La primera visita a una
/// sección ([ayudaSeccionId]) lo abre una sola vez y persiste el visto con
/// [AyudaVistaService] (clave `ayuda_vista_<seccion>`).
class AuthenticatedShell extends StatefulWidget {
  /// Ancho de referencia del diseño de escritorio.
  static const desktopBreakpoint = 1050.0;

  /// Ancho de la navegación izquierda fija (y del drawer).
  static const navigationWidth = 188.0;

  /// Ancho del panel de ayuda en modo overlay lateral.
  /// Se conserva el nombre histórico para no romper referencias.
  static const contextualPanelWidth = 320.0;

  /// Centro mínimo cómodo. Se conserva como referencia histórica.
  static const contenidoMinimoComodo = 640.0;

  /// Umbral que decide navegación fija vs [Drawer]. Se conserva el nombre
  /// histórico; ya NO controla ningún panel fijo y ya NO depende del ancho
  /// del overlay, para no mover la navegación lateral.
  static double get anchoMinimoTresColumnas => desktopBreakpoint;

  /// Por debajo de este ancho el overlay es bottom sheet.
  static const overlayBottomSheetBreakpoint = 800.0;

  static const helpButtonKey = Key('authenticated-shell-help-button');
  static const helpDialogKey = Key('authenticated-shell-help-dialog');
  static const helpCloseKey = Key('authenticated-shell-help-close');

  final AuthenticatedNavigationBuilder navigationBuilder;
  final AuthenticatedTopBarBuilder topBarBuilder;
  final Widget child;
  final Widget? contextualPanel;

  /// Identificador de la sección actual (p. ej. `inicio`, `productos`).
  /// Si es nulo no hay auto-apertura.
  final String? ayudaSeccionId;
  final AyudaVistaService? ayudaVistaService;

  const AuthenticatedShell({
    super.key,
    required this.navigationBuilder,
    required this.topBarBuilder,
    required this.child,
    this.contextualPanel,
    this.ayudaSeccionId,
    this.ayudaVistaService,
  });

  bool tresColumnas(double ancho) => ancho >= anchoMinimoTresColumnas;

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  bool _ayudaAbierta = false;
  String? _seccionVerificada;

  AyudaVistaService get _servicio =>
      widget.ayudaVistaService ?? AyudaVistaService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarAutoApertura());
  }

  @override
  void didUpdateWidget(covariant AuthenticatedShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ayudaSeccionId != widget.ayudaSeccionId ||
        oldWidget.contextualPanel != widget.contextualPanel) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _verificarAutoApertura(),
      );
    }
  }

  Future<void> _verificarAutoApertura() async {
    final seccion = widget.ayudaSeccionId;
    if (seccion == null || widget.contextualPanel == null) return;
    if (_seccionVerificada == seccion) return;
    _seccionVerificada = seccion;
    if (!mounted || _ayudaAbierta) return;
    bool vista = true;
    try {
      vista = await _servicio.yaVista(seccion);
    } catch (_) {
      return;
    }
    if (!mounted || vista) return;
    setState(() => _ayudaAbierta = true);
    try {
      await _servicio.marcarVista(seccion);
    } catch (_) {
      // Si no se puede persistir, la ayuda ya quedó abierta esta vez.
    }
  }

  void _abrirAyuda() {
    if (widget.contextualPanel == null) return;
    setState(() => _ayudaAbierta = true);
  }

  void _cerrarAyuda() {
    if (!_ayudaAbierta) return;
    setState(() => _ayudaAbierta = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final conNavegacionFija = ancho >= AuthenticatedShell.anchoMinimoTresColumnas;
        final conBotonAyuda = widget.contextualPanel != null;
        final esBottomSheet =
            ancho < AuthenticatedShell.overlayBottomSheetBreakpoint;
        return Scaffold(
          key: const Key('authenticated-shell'),
          backgroundColor: AppColors.fondo,
          drawer: conNavegacionFija ? null : _crearDrawer(),
          body: Stack(
            children: [
              Row(
                children: [
                  if (conNavegacionFija)
                    SizedBox(
                      key: const Key('authenticated-shell-navigation'),
                      width: AuthenticatedShell.navigationWidth,
                      child: Builder(
                        builder: (context) =>
                            widget.navigationBuilder(context, null),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Builder(
                            builder: (scaffoldContext) => widget.topBarBuilder(
                              scaffoldContext,
                              conNavegacionFija
                                  ? null
                                  : () => Scaffold.of(
                                      scaffoldContext,
                                    ).openDrawer(),
                              conBotonAyuda ? _abrirAyuda : null,
                            ),
                          ),
                        ),
                        Expanded(
                          child: KeyedSubtree(
                            key: const Key('authenticated-shell-content'),
                            child: widget.child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_ayudaAbierta && widget.contextualPanel != null)
                _AyudaOverlay(
                  esBottomSheet: esBottomSheet,
                  onCerrar: _cerrarAyuda,
                  child: widget.contextualPanel!,
                ),
            ],
          ),
        );
      },
    );
  }

  Drawer _crearDrawer() {
    return Drawer(
      width: AuthenticatedShell.navigationWidth,
      backgroundColor: AppColors.superficie,
      child: Builder(
        builder: (drawerContext) => widget.navigationBuilder(
          drawerContext,
          () => Navigator.of(drawerContext).pop(),
        ),
      ),
    );
  }
}

/// Overlay de ayuda: barrera que cierra al tocar fuera + panel con botón X.
/// Solo contenedor/presentación; el [child] es el contenido contextual tal cual.
class _AyudaOverlay extends StatelessWidget {
  final bool esBottomSheet;
  final VoidCallback onCerrar;
  final Widget child;

  const _AyudaOverlay({
    required this.esBottomSheet,
    required this.onCerrar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCerrar,
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
        if (esBottomSheet)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PanelAyuda(
              esBottomSheet: true,
              onCerrar: onCerrar,
              child: child,
            ),
          )
        else
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: _PanelAyuda(
              esBottomSheet: false,
              onCerrar: onCerrar,
              child: child,
            ),
          ),
      ],
    );
  }
}

class _PanelAyuda extends StatelessWidget {
  final bool esBottomSheet;
  final VoidCallback onCerrar;
  final Widget child;

  const _PanelAyuda({
    required this.esBottomSheet,
    required this.onCerrar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final alturaMax = MediaQuery.sizeOf(context).height;
    final alturaPanel = esBottomSheet
        ? alturaMax * 0.75
        : (alturaMax - 24).clamp(200.0, alturaMax);
    final panel = Material(
      key: AuthenticatedShell.helpDialogKey,
      color: AppColors.superficie,
      borderRadius: esBottomSheet
          ? const BorderRadius.vertical(top: Radius.circular(16))
          : const BorderRadius.horizontal(left: Radius.circular(16)),
      child: Container(
        width: esBottomSheet
            ? double.infinity
            : AuthenticatedShell.contextualPanelWidth,
        constraints: BoxConstraints(maxHeight: alturaPanel),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: esBottomSheet
              ? const BorderRadius.vertical(top: Radius.circular(16))
              : const BorderRadius.horizontal(left: Radius.circular(16)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 0, 4),
                        child: Text(
                          'Ayuda',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: AuthenticatedShell.helpCloseKey,
                      onPressed: onCerrar,
                      tooltip: 'Cerrar ayuda',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (esBottomSheet) return panel;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
        child: panel,
      ),
    );
  }
}
