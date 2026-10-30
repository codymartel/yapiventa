import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

void main() {
  FormatoPresentacion conteo(int n) => FormatoPresentacion(
    valorBase: n,
    familia: FamiliaUnidad.conteo,
    unidadVisible: RegistroUnidades.unidad,
  );

  group('FormatoPresentacion.textoVisible', () {
    test('el conteo va en plural: 30 unidades', () {
      expect(conteo(30).textoVisible, '30 unidades');
    });

    test('uno va en singular y la clave guardada no cambia', () {
      expect(conteo(1).textoVisible, '1 unidad');
      expect(conteo(30).etiqueta, '30 unidad');
    });

    test('las medidas se leen igual que la etiqueta', () {
      final botella = FormatoPresentacion(
        valorBase: 500,
        familia: FamiliaUnidad.volumen,
        unidadVisible: RegistroUnidades.ml,
      );
      expect(botella.textoVisible, botella.etiqueta);
    });
  });
}
