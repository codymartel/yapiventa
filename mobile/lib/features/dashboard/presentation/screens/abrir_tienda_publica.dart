import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../negocio/domain/models/progreso_configuracion.dart';
import 'dashboard_contenido_inicio.dart';

/// Cómo se abre un enlace afuera de la app (en pruebas se reemplaza).
typedef AbrirUrlDashboard =
    Future<bool> Function(Uri url, {String? webOnlyWindowName});

/// Abre la tienda pública del negocio en otra pestaña (`/[slug]` en el sitio
/// de tiendas). Si falta completar la configuración llama a [alBloquear]; si
/// falta la plantilla, o el navegador no puede abrirla, lo dice con un aviso.
Future<void> abrirTiendaPublica(
  BuildContext context, {
  required ProgresoConfiguracion progreso,
  required String slug,
  required VoidCallback alBloquear,
  AbrirUrlDashboard? abrirUrl,
}) async {
  if (!progreso.completo) {
    alBloquear();
    return;
  }
  if (slug.isEmpty || progreso.plantilla == null) {
    mostrarAvisoDashboard(
      context,
      'Selecciona una plantilla para publicar tu tienda web.',
    );
    return;
  }

  final url = Uri.https('yapiventa-tienda.web.app', '/$slug');
  try {
    final lanzarUrl = abrirUrl ?? launchUrl;
    final abierto = await lanzarUrl(url, webOnlyWindowName: '_blank');
    if (!abierto && context.mounted) {
      mostrarAvisoDashboard(
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
      mostrarAvisoDashboard(
        context,
        'Ocurrió un error al abrir la tienda web. Intenta de nuevo.',
      );
    }
  }
}
