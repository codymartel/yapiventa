import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/categoria_personalizada.dart';

void main() {
  group('canonicalizarCategoria', () {
    test('deja intacto un nombre ya canónico', () {
      expect(canonicalizarCategoria('bebidas'), 'bebidas');
    });

    test('pasa a minúsculas', () {
      expect(canonicalizarCategoria('BEBIDAS'), 'bebidas');
      expect(canonicalizarCategoria('Bebidas'), 'bebidas');
    });

    test('quita tildes y diéresis', () {
      expect(canonicalizarCategoria('Bebidas'), 'bebidas');
      expect(canonicalizarCategoria('Jamón'), 'jamon');
      expect(canonicalizarCategoria('Café'), 'cafe');
      expect(canonicalizarCategoria('Áticos'), 'aticos');
      expect(canonicalizarCategoria('Peluquería'), 'peluqueria');
      expect(canonicalizarCategoria('Ímpetu'), 'impetu');
    });

    test('trata la ñ como n', () {
      expect(canonicalizarCategoria('Niños'), 'ninos');
      expect(canonicalizarCategoria('Año'), 'ano');
    });

    test('colapsa espacios, tabs y saltos de línea a un solo espacio', () {
      expect(canonicalizarCategoria('Cuidado   personal'), 'cuidado personal');
      expect(canonicalizarCategoria('Cuidado\tpersonal'), 'cuidado personal');
      expect(canonicalizarCategoria('Cuidado\npersonal'), 'cuidado personal');
      expect(
        canonicalizarCategoria('  Cuidado \n\t personal  '),
        'cuidado personal',
      );
    });

    test('recorta los bordes', () {
      expect(canonicalizarCategoria('  Bebidas  '), 'bebidas');
    });

    test('conserva la puntuación sin fundir nombres distintos', () {
      expect(
        canonicalizarCategoria('Bebidas & Snacks'),
        'bebidas & snacks',
      );
      expect(
        canonicalizarCategoria('Bebidas y Snacks'),
        'bebidas y snacks',
      );
      expect(
        canonicalizarCategoria('Bebidas & Snacks'),
        isNot(canonicalizarCategoria('Bebidas y Snacks')),
      );
    });

    test('devuelve vacío cuando solo hay espacios', () {
      expect(canonicalizarCategoria(''), '');
      expect(canonicalizarCategoria('   '), '');
    });

    test('es idempotente: canonicalizar la clave devuelve la clave', () {
      const nombres = ['Jamón', '  Cuidado  personal ', 'Ñoño', 'BEBIDAS'];
      for (final nombre in nombres) {
        final clave = canonicalizarCategoria(nombre);
        expect(canonicalizarCategoria(clave), clave);
      }
    });
  });

  group('CategoriaPersonalizada.crear', () {
    test('deriva la clave del nombre y recorta el nombre', () {
      final categoria = CategoriaPersonalizada.crear('  Cuidado Personal ');

      expect(categoria.clave, 'cuidado personal');
      expect(categoria.nombre, 'Cuidado Personal');
      expect(categoria.activa, isTrue);
    });

    test('respeta activa: false al crearla', () {
      final categoria = CategoriaPersonalizada.crear('Temporal', activa: false);

      expect(categoria.activa, isFalse);
      expect(categoria.clave, 'temporal');
    });

    test('dos nombres que canonicalizan igual producen la misma clave', () {
      final a = CategoriaPersonalizada.crear('Jamón');
      final b = CategoriaPersonalizada.crear('  jamon  ');

      expect(a.clave, b.clave);
      expect(a.clave, 'jamon');
      // El nombre visible conserva lo que escribió cada uno.
      expect(a.nombre, 'Jamón');
      expect(b.nombre, 'jamon');
    });
  });

  group('CategoriaPersonalizada', () {
    test('activa por defecto', () {
      const categoria = CategoriaPersonalizada(
        clave: 'temporal',
        nombre: 'Temporal',
      );

      expect(categoria.activa, isTrue);
    });

    test('copyWith cambia solo lo indicado', () {
      final categoria = CategoriaPersonalizada.crear('Temporal');

      final desactivada = categoria.copyWith(activa: false);
      expect(desactivada.activa, isFalse);
      expect(desactivada.clave, categoria.clave);
      expect(desactivada.nombre, categoria.nombre);

      final renombrada = categoria.copyWith(nombre: 'Temporales');
      expect(renombrada.nombre, 'Temporales');
      expect(renombrada.activa, isTrue);
    });

    test('renombrar conserva la clave', () {
      final categoria = CategoriaPersonalizada.crear('Temporal');
      final renombrada = categoria.renombrar('  Temporada  ');

      expect(renombrada.nombre, 'Temporada');
      expect(renombrada.clave, categoria.clave);
      expect(renombrada.clave, 'temporal');
    });

    test('desactivar no es eliminar: conserva la identidad', () {
      final categoria = CategoriaPersonalizada.crear('Temporal');
      final desactivada = categoria.copyWith(activa: false);

      expect(desactivada.clave, categoria.clave);
      expect(desactivada, isNot(categoria));
    });

    test('igualdad por valor, incluyendo activa', () {
      final a = CategoriaPersonalizada.crear('Temporal');
      final b = CategoriaPersonalizada.crear('Temporal');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(activa: false)));
    });

    test('un Set deduplica registros idénticos', () {
      final a = CategoriaPersonalizada.crear('Temporal');
      final b = CategoriaPersonalizada.crear('Temporal');
      final c = CategoriaPersonalizada.crear('Permanente');

      final conjunto = {a, b, c};

      expect(conjunto, hasLength(2));
    });

    test(
      'misma clave con distinto nombre sigue siendo un registro distinto: '
      'así se detecta el conflicto de nombre',
      () {
        final a = CategoriaPersonalizada.crear('Temporal');
        final b = CategoriaPersonalizada.crear('  temporal ');

        expect(a.clave, b.clave);
        expect(a, isNot(b));
        expect({a, b}, hasLength(2));
      },
    );
  });

  group('CategoriaPersonalizada.validar', () {
    test('acepta una categoría creada correctamente', () {
      expect(CategoriaPersonalizada.crear('Cuidado Personal').validar(), isNull);
    });

    test('rechaza nombre vacío', () {
      const categoria = CategoriaPersonalizada(
        clave: 'algo',
        nombre: '   ',
      );

      expect(categoria.validar(), contains('no puede estar vacío'));
    });

    test('rechaza clave vacía', () {
      const categoria = CategoriaPersonalizada(clave: '', nombre: 'Algo');

      expect(categoria.validar(), contains('no puede estar vacía'));
    });

    test('rechaza una clave que no es canónica', () {
      const categoria = CategoriaPersonalizada(
        clave: 'Cuidado Personal',
        nombre: 'Cuidado Personal',
      );

      expect(categoria.validar(), contains('no es canónica'));
    });
  });
}
