import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/data/mappers/estructura_producto_mapper.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

void main() {
  test('ida y vuelta: partes, ids sueltos y suma guardada', () {
    final combo = Producto(
      id: 'c1',
      negocioId: 'n1',
      nombre: 'Combo familiar',
      precioCentavos: 2800,
      sumaPartesCentavos: 3200,
      partes: const [
        ParteCombo(
          productoId: 'pollo',
          cantidad: 1,
          nombre: 'Pollo ¼',
          urlImagen: 'https://x/pollo.png',
        ),
        ParteCombo(
          productoId: 'polo',
          modeloId: 'azul',
          filaId: 'm',
          cantidad: 2,
          nombre: 'Polo · Azul · M',
        ),
        ParteCombo(productoId: 'pollo', modeloId: 'x', cantidad: 1),
      ],
    );

    final mapa = ProductoFirestoreMapper.paraFirestore(combo);

    expect(mapa['partesProductoIds'], ['pollo', 'polo']);
    expect(mapa['sumaPartesCentavos'], 3200);

    final leido = ProductoFirestoreMapper.desdeFirestore('c1', mapa)!;
    expect(leido.esCombo, isTrue);
    expect(leido.partes, hasLength(3));
    expect(leido.partes[1].modeloId, 'azul');
    expect(leido.partes[1].cantidad, 2);
    expect(leido.partes[0].urlImagen, 'https://x/pollo.png');
    expect(leido.sumaPartesCentavos, 3200);
  });

  test('un producto normal no tiene partes', () {
    final leido = ProductoFirestoreMapper.desdeFirestore('p', {
      'negocioId': 'n',
      'nombre': 'Cafe',
    })!;

    expect(leido.esCombo, isFalse);
    expect(leido.partes, isEmpty);
    expect(leido.sumaPartesCentavos, 0);
  });

  test('lectura defensiva: sin producto o cantidad menor que 1 se ignora', () {
    final partes = EstructuraProductoMapper.partesDesde([
      {'productoId': '', 'cantidad': 1},
      {'productoId': 'a', 'cantidad': 0},
      'basura',
      {'productoId': 'b', 'cantidad': 3},
    ]);

    expect(partes.map((p) => p.productoId), ['b']);
    expect(partes.single.cantidad, 3);
  });

  test('nunca pasa del máximo y un valor que no es lista da vacío', () {
    final partes = EstructuraProductoMapper.partesDesde([
      for (var i = 0; i < 15; i++) {'productoId': 'p$i', 'cantidad': 1},
    ]);

    expect(partes, hasLength(ParteCombo.maximo));
    expect(EstructuraProductoMapper.partesDesde(null), isEmpty);
  });
}
