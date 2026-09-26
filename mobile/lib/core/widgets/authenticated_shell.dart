import 'package:flutter/material.dart';

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
/// Decide con [LayoutBuilder] sobre el ancho local disponible (no con el
/// [MediaQuery] global) y prioriza siempre el contenido central. Hay un único
/// umbral, [anchoMinimoTresColumnas], del que dependen AMBAS decisiones (navegación
/// fija y panel fijo), de modo que no puede existir una franja contradictoria en la
/// que una columna esté fija y la otra no:
///
///  - A partir de [anchoMinimoTresColumnas]: navegación izquierda fija
///    ([navigationWidth]) + panel contextual derecho ([contextualPanelWidth]) y el
///    resto del ancho para el contenido.
///  - Por debajo de ese umbral: la navegación pasa a [Drawer] y NO hay panel
///    contextual fijo. El contenido ocupa todo el ancho disponible; la ayuda se
///    alcanza desde una acción pequeña en la barra superior, nunca desde un panel
///    colocado encima del contenido.
class AuthenticatedShell extends StatelessWidget {
  /// Ancho de referencia del diseño de escritorio.
  static const desktopBreakpoint = 1050.0;

  /// Ancho de la navegación izquierda fija (y del drawer).
  static const navigationWidth = 188.0;

  /// Ancho del panel contextual derecho fijo.
  static const contextualPanelWidth = 220.0;

  /// Centro mínimo cómodo cuando ambos laterales son visibles.
  static const contenidoMinimoComodo = 640.0;

  /// Única fuente de verdad del corte a tres columnas. Es el mayor entre el
  /// [desktopBreakpoint] y la suma de los dos laterales más el centro mínimo, de
  /// modo que navegación fija y panel fijo aparecen y desaparecen a la vez.
  static double get anchoMinimoTresColumnas {
    const suma = navigationWidth + contextualPanelWidth + contenidoMinimoComodo;
    return suma > desktopBreakpoint ? suma : desktopBreakpoint;
  }

  static const helpButtonKey = Key('authenticated-shell-help-button');
  static const helpDialogKey = Key('authenticated-shell-help-dialog');

  final AuthenticatedNavigationBuilder navigationBuilder;
  final AuthenticatedTopBarBuilder topBarBuilder;
  final Widget child;
  final Widget? contextualPanel;

  const AuthenticatedShell({
    super.key,
    required this.navigationBuilder,
    required this.topBarBuilder,
    required this.child,
    this.contextualPanel,
  });

  bool tresColumnas(double ancho) => ancho >= anchoMinimoTresColumnas;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final conTresColumnas = tresColumnas(ancho);
        final conPanelFijo = conTresColumnas && contextualPanel != null;
        final conAyudaFlotante =
            !conPanelFijo && contextualPanel != null;
        return Scaffold(
          key: const Key('authenticated-shell'),
          backgroundColor: AppColors.fondo,
          drawer: conTresColumnas ? null : _crearDrawer(),
          body: Row(
            children: [
              if (conTresColumnas)
                SizedBox(
                  key: const Key('authenticated-shell-navigation'),
                  width: navigationWidth,
                  child: Builder(
                    builder: (context) => navigationBuilder(context, null),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Builder(
                        builder: (scaffoldContext) => topBarBuilder(
                          scaffoldContext,
                          conTresColumnas
                              ? null
                              : () =>
                                    Scaffold.of(scaffoldContext).openDrawer(),
                          conAyudaFlotante
                              ? () => _abrirAyuda(context)
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: conPanelFijo
                          ? _DesktopBody(
                              contextualPanel: contextualPanel,
                              child: child,
                            )
                          : _ContentOnly(child: child),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirAyuda(BuildContext context) {
    final panel = contextualPanel;
    if (panel == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: helpDialogKey,
        backgroundColor: AppColors.superficie,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: panel,
          ),
        ),
      ),
    );
  }

  Drawer _crearDrawer() {
    return Drawer(
      width: navigationWidth,
      backgroundColor: AppColors.superficie,
      child: Builder(
        builder: (drawerContext) => navigationBuilder(
          drawerContext,
          () => Navigator.of(drawerContext).pop(),
        ),
      ),
    );
  }
}

class _DesktopBody extends StatelessWidget {
  final Widget child;
  final Widget? contextualPanel;

  const _DesktopBody({required this.child, required this.contextualPanel});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KeyedSubtree(
            key: const Key('authenticated-shell-content'),
            child: child,
          ),
        ),
        if (contextualPanel != null)
          Container(
            key: const Key('authenticated-shell-contextual-panel'),
            width: AuthenticatedShell.contextualPanelWidth,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            decoration: BoxDecoration(
              color: AppColors.fondo,
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(child: contextualPanel),
          ),
      ],
    );
  }
}

/// Cuerpo sin panel contextual: el contenido ocupa todo el ancho disponible.
/// La ayuda se abre bajo demanda desde la barra superior, de modo que nada se
/// coloca por encima del módulo.
class _ContentOnly extends StatelessWidget {
  final Widget child;

  const _ContentOnly({required this.child});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('authenticated-shell-content'),
      child: child,
    );
  }
}
