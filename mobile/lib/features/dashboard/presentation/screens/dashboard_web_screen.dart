import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/authenticated_shell.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../providers/dashboard_provider.dart';
import '../state/dashboard_ui_state.dart';
import '../widgets/dashboard_attention_panel.dart';
import '../widgets/dashboard_home_content.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/dashboard_top_bar.dart';

typedef AbrirUrlDashboard =
    Future<bool> Function(Uri url, {String? webOnlyWindowName});

class DashboardWebScreen extends StatelessWidget {
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
        email: email,
        onCerrarSesion: onCerrarSesion,
      ),
      contextualPanel: DashboardAttentionPanel(
        items: state.necesitanAtencion,
        productos: state.productosDestacados,
      ),
      child: DashboardHomeContent(
        state: state,
        progreso: progreso,
        onAbrirEtapa: onAbrirEtapa,
        onAgregarProducto: () => progreso.negocioCompleto
            ? onAbrirEtapa(EtapaConfiguracion.productos)
            : _mostrarBloqueado(context),
        onActualizarStock: () => _mostrarProximamente(
          context,
          'El módulo de stock estará disponible próximamente.',
        ),
        onVerPedidos: () => _mostrarProximamente(
          context,
          'El módulo de pedidos estará disponible próximamente.',
        ),
        onResponderQueja: () => _mostrarProximamente(
          context,
          'El módulo de reclamaciones estará disponible próximamente.',
        ),
      ),
    );
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
        onAbrirEtapa(EtapaConfiguracion.productos);
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
        onAbrirEtapa(EtapaConfiguracion.negocio);
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
    if (!progreso.productosCompletos) {
      _mostrarBloqueado(context);
      return;
    }
    onAbrirEtapa(EtapaConfiguracion.plantilla);
  }

  Future<void> _verTiendaWeb(BuildContext context) async {
    if (!progreso.completo) {
      _mostrarBloqueado(context);
      return;
    }
    if (progreso.slug.isEmpty || progreso.plantilla == null) {
      _mostrarProximamente(
        context,
        'Selecciona una plantilla para publicar tu tienda web.',
      );
      return;
    }

    final url = Uri.https('yapiventa-tienda.web.app', '/${progreso.slug}');
    try {
      final lanzarUrl = abrirUrl ?? launchUrl;
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  bool _destinoHabilitado(DashboardDestination destino) => switch (destino) {
    DashboardDestination.inicio => true,
    DashboardDestination.productos => progreso.negocioCompleto,
    DashboardDestination.configuracion => progreso.rubroCompleto,
    _ => progreso.completo,
  };

  String _nombreNegocio(DashboardUiState state) {
    final nombre = progreso.catalogo.configuracionInicial['nombreNegocio'];
    return nombre is String && nombre.trim().isNotEmpty
        ? nombre.trim()
        : state.nombreNegocio;
  }

  void _mostrarBloqueado(BuildContext context) {
    _mostrarProximamente(
      context,
      'Completa primero las etapas pendientes de configuración.',
    );
  }
}
