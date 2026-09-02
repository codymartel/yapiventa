import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/routing/app_router.dart';
import 'package:mobile/core/routing/rutas.dart';

void main() {
  test('el mapa de rutas registra exactamente las rutas declaradas', () {
    expect(appRoutes.keys.toSet(), Rutas.declaradas);
  });

  test('generarRuta arma /configurar-negocio con el rubro como argumento', () {
    final ruta = generarRuta(
      const RouteSettings(name: Rutas.configurarNegocio, arguments: 'Bodega'),
    );
    expect(ruta, isA<MaterialPageRoute<dynamic>>());
  });

  test('generarRuta devuelve null para nombres desconocidos', () {
    expect(generarRuta(const RouteSettings(name: '/no-existe')), isNull);
  });

  test('toda ruta navegable está declarada o se genera', () {
    for (final ruta in Rutas.todas) {
      final resuelta = appRoutes.containsKey(ruta) ||
          generarRuta(RouteSettings(name: ruta, arguments: 'Bodega')) != null;
      expect(resuelta, isTrue, reason: 'ruta sin registrar: $ruta');
    }
  });
}
