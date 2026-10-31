import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/calculo_combo.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

Producto _producto(
  String id,
  String nombre,
  int precio,
  int stock, {
  bool infinito = false,
}) => Producto(
  id: id,
  negocioId: 'n',
  nombre: nombre,
  precioCentavos: precio,
  stock: stock,
  esStockInfinito: infinito,
);

void main() {
  final pollo = _producto('pollo', 'Pollo ¼', 1800, 10);
  final papas = _producto('papas', 'Papas', 600, 7);
  final gaseosa = _producto('gaseosa', 'Gaseosa 500 ml', 400, 9);
  final todos = {
    for (final p in [pollo, papas, gaseosa]) p.id: p,
  };

  const partes = [
    ParteCombo(productoId: 'pollo', cantidad: 1, nombre: 'Pollo ¼'),
    ParteCombo(productoId: 'papas', cantidad: 1, nombre: 'Papas'),
    ParteCombo(productoId: 'gaseosa', cantidad: 2, nombre: 'Gaseosa 500 ml'),
  ];

  test('suma las partes en céntimos: 1800 + 600 + 400 × 2 = 3200', () {
    final r = CalculoCombo.calcular(partes, (id) => todos[id]);

    expect(r.sumaCentavos, 3200);
  });

  test('el stock es el menor de stock ÷ cantidad, con piso', () {
    final r = CalculoCombo.calcular(partes, (id) => todos[id]);

    // pollo 10, papas 7, gaseosa 9 ÷ 2 = 4
    expect(r.stock, 4);
    expect(r.limita, 'Gaseosa 500 ml');
    expect(r.agotado, isFalse);
    expect(r.sinDatos, isFalse);
  });

  test('una parte sin stock agota el combo y dice cuál', () {
    final sinPapas = {...todos, 'papas': _producto('papas', 'Papas', 600, 0)};

    final r = CalculoCombo.calcular(partes, (id) => sinPapas[id]);

    expect(r.stock, 0);
    expect(r.agotado, isTrue);
    expect(r.limita, 'Papas');
  });

  test('una parte con stock infinito no limita', () {
    final infinito = {
      ...todos,
      'gaseosa': _producto('gaseosa', 'Gaseosa', 400, 0, infinito: true),
    };

    final r = CalculoCombo.calcular(partes, (id) => infinito[id]);

    expect(r.stock, 7);
    expect(r.limita, 'Papas');
  });

  test('si todas las partes son infinitas, el combo también', () {
    final infinitos = {
      for (final p in todos.values)
        p.id: _producto(p.id, p.nombre, p.precioCentavos, 0, infinito: true),
    };

    final r = CalculoCombo.calcular(partes, (id) => infinitos[id]);

    expect(r.ilimitado, isTrue);
    expect(r.stock, isNull);
    expect(r.agotado, isFalse);
  });

  test('sin un producto no se inventa nada: sinDatos', () {
    final r = CalculoCombo.calcular(
      partes,
      (id) => id == 'papas' ? null : todos[id],
    );

    expect(r.sinDatos, isTrue);
    expect(r.sumaCentavos, isNull);
    expect(r.stock, isNull);
  });

  test('con variables usa el precio y el stock de la fila elegida', () {
    final polo = Producto(
      id: 'polo',
      negocioId: 'n',
      nombre: 'Polo',
      precioCentavos: 3500,
      stock: 13,
      modelos: const [
        ModeloProducto(
          id: 'azul',
          nombre: 'Azul',
          filas: [
            FilaVenta(id: 'm', etiqueta: 'M', precioCentavos: 3500, stock: 8),
            FilaVenta(id: 'l', etiqueta: 'L', precioCentavos: 4000, stock: 5),
          ],
        ),
      ],
    );

    final r = CalculoCombo.calcular(const [
      ParteCombo(
        productoId: 'polo',
        modeloId: 'azul',
        filaId: 'l',
        cantidad: 2,
        nombre: 'Polo · Azul · L',
      ),
    ], (id) => polo);

    expect(r.sumaCentavos, 8000);
    expect(r.stock, 2);
  });

  test('una fila que ya no existe cuenta como sin datos', () {
    final polo = Producto(
      id: 'polo',
      negocioId: 'n',
      nombre: 'Polo',
      modelos: const [ModeloProducto(id: 'azul', nombre: 'Azul')],
    );

    final r = CalculoCombo.calcular(const [
      ParteCombo(
        productoId: 'polo',
        modeloId: 'azul',
        filaId: 'x',
        cantidad: 1,
      ),
    ], (id) => polo);

    expect(r.sinDatos, isTrue);
  });
}
