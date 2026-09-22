import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

typedef AuthenticatedNavigationBuilder =
    Widget Function(BuildContext context, VoidCallback? closeNavigation);
typedef AuthenticatedTopBarBuilder =
    Widget Function(BuildContext context, VoidCallback? openNavigation);

class AuthenticatedShell extends StatelessWidget {
  static const desktopBreakpoint = 1050.0;
  static const navigationWidth = 252.0;
  static const contextualPanelWidth = 320.0;

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esDesktop = constraints.maxWidth >= desktopBreakpoint;
        return Scaffold(
          key: const Key('authenticated-shell'),
          backgroundColor: AppColors.fondo,
          drawer: esDesktop ? null : _crearDrawer(),
          body: Row(
            children: [
              if (esDesktop)
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
                          esDesktop
                              ? null
                              : () => Scaffold.of(scaffoldContext).openDrawer(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: esDesktop
                          ? _DesktopBody(
                              contextualPanel: contextualPanel,
                              child: child,
                            )
                          : _CompactBody(
                              contextualPanel: contextualPanel,
                              child: child,
                            ),
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
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
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

class _CompactBody extends StatelessWidget {
  final Widget child;
  final Widget? contextualPanel;

  const _CompactBody({required this.child, required this.contextualPanel});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            if (contextualPanel != null)
              Material(
                color: AppColors.superficie,
                child: ExpansionTile(
                  key: const Key('authenticated-shell-contextual-expansion'),
                  collapsedIconColor: AppColors.blueLt,
                  iconColor: AppColors.blueLt,
                  shape: Border(bottom: BorderSide(color: AppColors.border)),
                  collapsedShape: Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                  title: const Text(
                    'Ayuda contextual',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.45,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                        child: contextualPanel,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: KeyedSubtree(
                key: const Key('authenticated-shell-content'),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
