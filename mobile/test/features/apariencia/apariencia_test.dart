import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/apariencia/data/apariencia_repository.dart';
import 'package:mobile/features/apariencia/domain/tamano_letra.dart';
import 'package:mobile/features/apariencia/presentation/providers/apariencia_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TamanoLetra', () {
    test('lee la clave guardada y cae a Normal si no la reconoce', () {
      expect(TamanoLetra.desdeClave('grande'), TamanoLetra.grande);
      expect(TamanoLetra.desdeClave('muy_grande'), TamanoLetra.muyGrande);
      expect(TamanoLetra.desdeClave(null), TamanoLetra.normal);
      expect(TamanoLetra.desdeClave('enorme'), TamanoLetra.normal);
    });

    test('multiplica la escala del teléfono por la elegida', () {
      expect(TamanoLetra.normal.escalaCon(1), 1);
      expect(TamanoLetra.grande.escalaCon(1), closeTo(1.15, 1e-9));
      expect(TamanoLetra.muyGrande.escalaCon(1), closeTo(1.3, 1e-9));
      expect(TamanoLetra.grande.escalaCon(1.2), closeTo(1.38, 1e-9));
    });

    test('no pasa del tope, pero respeta un teléfono que ya lo pasa', () {
      expect(TamanoLetra.muyGrande.escalaCon(1.3), TamanoLetra.escalaMaxima);
      expect(TamanoLetra.muyGrande.escalaCon(2), 2);
      expect(TamanoLetra.normal.escalaCon(2), 2);
    });
  });

  group('AparienciaRepository', () {
    test('sin nada guardado devuelve Normal', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await AparienciaRepository().leerTamanoLetra(),
        TamanoLetra.normal,
      );
    });

    test('guarda y vuelve a leer el tamaño', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = AparienciaRepository();
      expect(await repo.guardarTamanoLetra(TamanoLetra.muyGrande), isTrue);
      expect(await repo.leerTamanoLetra(), TamanoLetra.muyGrande);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AparienciaRepository.claveTamanoLetra),
        'muy_grande',
      );
    });

    test('si el equipo no deja leer ni guardar, sigue con Normal', () async {
      final repo = AparienciaRepository(
        obtenerPrefs: () => Future.error(Exception('sin almacenamiento')),
      );
      expect(await repo.leerTamanoLetra(), TamanoLetra.normal);
      expect(await repo.guardarTamanoLetra(TamanoLetra.grande), isFalse);
    });
  });

  group('AparienciaProvider', () {
    test('cargar trae lo guardado antes de abrir la app', () async {
      SharedPreferences.setMockInitialValues({
        AparienciaRepository.claveTamanoLetra: 'grande',
      });
      final provider = await AparienciaProvider.cargar();
      expect(provider.tamanoLetra, TamanoLetra.grande);
    });

    test('cambiar avisa al instante y lo guarda', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AparienciaProvider();
      var avisos = 0;
      provider.addListener(() => avisos++);

      await provider.cambiarTamanoLetra(TamanoLetra.muyGrande);
      await provider.cambiarTamanoLetra(TamanoLetra.muyGrande);

      expect(provider.tamanoLetra, TamanoLetra.muyGrande);
      expect(avisos, 1);
      expect(
        await AparienciaRepository().leerTamanoLetra(),
        TamanoLetra.muyGrande,
      );
    });

    test('si no se puede guardar, el cambio vale igual', () async {
      final provider = AparienciaProvider(
        repository: AparienciaRepository(
          obtenerPrefs: () => Future.error(Exception('sin almacenamiento')),
        ),
      );
      await provider.cambiarTamanoLetra(TamanoLetra.grande);
      expect(provider.tamanoLetra, TamanoLetra.grande);
    });
  });
}
