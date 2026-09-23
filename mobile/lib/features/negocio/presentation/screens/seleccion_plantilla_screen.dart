import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/seleccion_plantilla_info.dart';
import '../../seleccion_plantilla_dependencies.dart';
import '../widgets/seleccion_plantilla_content.dart';
import '../widgets/seleccion_plantilla_flow.dart';

typedef AbrirUrlTienda =
    Future<bool> Function(Uri url, {String? webOnlyWindowName});

// ═════════════════════════════════════════════════════════════════════════
// SeleccionPlantillaScreen
// ═════════════════════════════════════════════════════════════════════════
// Wrapper de ruta de la selección de plantilla web (patrón
// ConfiguracionNegocioScreen). Conserva únicamente el andamiaje de
// navegación (Scaffold + SafeArea) y la apertura de la tienda pública con
// url_launcher (onVerTienda); la creación del provider, la carga, la
// selección, el guardado, los errores, el bloqueo, el PopScope y los
// callbacks viven en SeleccionPlantillaFlow.
// ═════════════════════════════════════════════════════════════════════════

class SeleccionPlantillaScreen extends StatelessWidget {
  final String uid;

  /// Rubro del negocio (Bodega, Restaurante, Ropa, Farmacia, Ferretería…).
  /// Solo se usa para el subtítulo; no condiciona la selección.
  final String rubro;

  /// Selección ya persistida (progreso de la sesión). Con ella el flow
  /// arranca cargado sin releer el repositorio.
  final SeleccionPlantillaInfo? seleccionInicial;

  final SeleccionPlantillaDependencies? dependencies;

  /// Regresa a donde estaba el embebedor (botón "Ir al dashboard").
  final VoidCallback onVolver;

  /// "Finalizar": el flujo ya guardó y recargó; aquí solo se regresa al inicio.
  final VoidCallback onCompletado;

  /// Recarga el progreso de la sesión tras guardar (p. ej. acceso.recargar()).
  final Future<void> Function()? recargarProgreso;

  final AbrirUrlTienda? abrirUrl;

  const SeleccionPlantillaScreen({
    super.key,
    required this.uid,
    this.rubro = '',
    this.seleccionInicial,
    this.dependencies,
    required this.onVolver,
    required this.onCompletado,
    this.recargarProgreso,
    this.abrirUrl,
  });

  Future<void> _verTiendaWeb(BuildContext context, String slug) async {
    final url = Uri.https('yapiventa-tienda.web.app', '/$slug');
    try {
      final abrirUrl = this.abrirUrl ?? launchUrl;
      final abierto = await abrirUrl(url, webOnlyWindowName: '_blank');
      if (!abierto && context.mounted) {
        _mostrarMensaje(context, 'El navegador no pudo abrir la tienda web.');
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error al abrir la tienda publica (${url.host}): '
        '${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _mostrarMensaje(
          context,
          'Ocurrió un error al abrir la tienda web. Intenta de nuevo.',
        );
      }
    }
  }

  void _mostrarMensaje(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeleccionPlantillaContent.fondo,
      body: SafeArea(
        child: SeleccionPlantillaFlow(
          uid: uid,
          rubro: rubro,
          seleccionInicial: seleccionInicial,
          dependencies: dependencies,
          onVolver: onVolver,
          onCompletado: onCompletado,
          recargarProgreso: recargarProgreso,
          onVerTienda: (slug) => _verTiendaWeb(context, slug),
        ),
      ),
    );
  }
}
