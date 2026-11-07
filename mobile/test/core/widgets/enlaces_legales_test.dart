import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/enlaces_legales.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  testWidgets('muestra los dos enlaces y abre cada página legal', (
    tester,
  ) async {
    final abiertas = <Uri>[];
    LaunchMode? modo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnlacesLegales(
            abrirUrl: (url, {mode = LaunchMode.platformDefault}) async {
              abiertas.add(url);
              modo = mode;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Política de privacidad'));
    await tester.tap(find.text('Términos de uso'));

    expect(abiertas, [UrlsLegales.privacidad, UrlsLegales.terminos]);
    expect(modo, LaunchMode.externalApplication);
  });

  test('las direcciones apuntan a las páginas publicadas con el panel', () {
    expect(
      UrlsLegales.privacidad.toString(),
      'https://yapiventa.web.app/privacidad.html',
    );
    expect(
      UrlsLegales.terminos.toString(),
      'https://yapiventa.web.app/terminos.html',
    );
  });

  testWidgets('en 320 px de ancho no desborda', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EnlacesLegales())),
    );

    expect(tester.takeException(), isNull);
  });
}
