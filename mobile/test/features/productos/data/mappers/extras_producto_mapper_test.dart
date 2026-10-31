import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/data/mappers/estructura_producto_mapper.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

void main() {
  group('extras en el documento del producto', () {
    test('ida y vuelta: nombre y precio en céntimos enteros', () {
      final producto = Producto(
        id: 'p1',
        negocioId: 'n1',
        nombre: 'Pollo a la brasa',
        precioCentavos: 1800,
        extras: const [
          ExtraProducto(id: 'e1', nombre: 'Con ají'),
          ExtraProducto(id: 'e2', nombre: 'Papas', precioCentavos: 600),
        ],
      );

      final mapa = ProductoFirestoreMapper.paraFirestore(producto);
      expect(mapa['extras'], [
        {'id': 'e1', 'nombre': 'Con ají', 'precioCentavos': 0},
        {'id': 'e2', 'nombre': 'Papas', 'precioCentavos': 600},
      ]);

      final leido = ProductoFirestoreMapper.desdeFirestore('p1', mapa)!;
      expect(leido.extras, hasLength(2));
      expect(leido.extras[1].nombre, 'Papas');
      expect(leido.extras[1].precioCentavos, 600);
    });

    test('un producto antiguo sin extras da lista vacía', () {
      final leido = ProductoFirestoreMapper.desdeFirestore('p1', {
        'negocioId': 'n1',
        'nombre': 'Cafe',
      })!;

      expect(leido.extras, isEmpty);
    });

    test('lectura defensiva: sin nombre se ignora y el precio no baja de 0', () {
      final extras = EstructuraProductoMapper.extrasDesde([
        {'id': 'a', 'nombre': '   ', 'precioCentavos': 500},
        'basura',
        {'nombre': 'Papas', 'precioCentavos': -300},
        {'id': 'c', 'nombre': 'Ensalada', 'precioCentavos': 400},
      ]);

      expect(extras.map((e) => e.nombre), ['Papas', 'Ensalada']);
      expect(extras.first.precioCentavos, 0);
      expect(extras.first.id, 'e2');
    });

    test('nunca pasa del máximo', () {
      final extras = EstructuraProductoMapper.extrasDesde([
        for (var i = 0; i < 15; i++) {'id': 'x$i', 'nombre': 'Extra $i'},
      ]);

      expect(extras, hasLength(ExtraProducto.maximo));
    });

    test('un valor que no es lista da vacío', () {
      expect(EstructuraProductoMapper.extrasDesde(null), isEmpty);
      expect(EstructuraProductoMapper.extrasDesde('x'), isEmpty);
    });
  });
}
