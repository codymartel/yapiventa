import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Páginas legales publicadas junto al panel. Google Play exige que la
/// política de privacidad también se pueda abrir dentro de la app.
class UrlsLegales {
  static final privacidad = Uri.parse(
    'https://yapiventa.web.app/privacidad.html',
  );
  static final terminos = Uri.parse('https://yapiventa.web.app/terminos.html');
}

typedef AbrirUrlLegal = Future<bool> Function(Uri url, {LaunchMode mode});

/// Abre una página legal en el navegador.
Future<bool> abrirEnlaceLegal(Uri url, {AbrirUrlLegal? abrirUrl}) {
  return (abrirUrl ?? launchUrl)(url, mode: LaunchMode.externalApplication);
}

/// «Política de privacidad · Términos de uso», para el pie de las pantallas
/// de acceso.
class EnlacesLegales extends StatelessWidget {
  final AbrirUrlLegal? abrirUrl;

  const EnlacesLegales({super.key, this.abrirUrl});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        _Enlace(
          texto: 'Política de privacidad',
          onTap: () =>
              abrirEnlaceLegal(UrlsLegales.privacidad, abrirUrl: abrirUrl),
        ),
        Text('·', style: TextStyle(color: AppColors.hint)),
        _Enlace(
          texto: 'Términos de uso',
          onTap: () =>
              abrirEnlaceLegal(UrlsLegales.terminos, abrirUrl: abrirUrl),
        ),
      ],
    );
  }
}

class _Enlace extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;

  const _Enlace({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: AppColors.blueLt,
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
