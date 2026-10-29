import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/data/mappers/estructura_producto_mapper.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

Producto _polo() => Producto(
  id: 'p1',
  negocioId: 'n1',
  nombre: 'Polo básico',
  modoVenta: ModoVenta.presentacion,
  presentacionId: 'unidad',
  precioCentavos: 3500,
  stock: 12,
  tituloModelos: 'Color',
  tituloFilas: 'Talla',
  modelos: const [
    ModeloProducto(
      id: 'azul',
      nombre: 'Azul',
      urlImagen: 'https://img.test/azul.jpg',
      cloudinaryPublicId: 'productos/azul',
      filas: [
        FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 4),
        FilaVenta(id: 'm', etiqueta: 'M', precioCentavos: 3500, stock: 6),
        FilaVenta(id: 'l', etiqueta: 'L', precioCentavos: 3800, stock: 2),
      ],
    ),
  ],
);

void main() {
  group('ida y vuelta', () {
    test('modelos y filas se guardan y se leen iguales', () {
      final datos = ProductoFirestoreMapper.paraFirestore(_polo());
      final leido = ProductoFirestoreMapper.desdeFirestore('p1', datos)!;

      expect(leido.tituloModelos, 'Color');
      expect(leido.tituloFilas, 'Talla');
      expect(leido.modelos, hasLength(1));
      final azul = leido.modelos.single;
      expect(azul.id, 'azul');
      expect(azul.nombre, 'Azul');
      expect(azul.urlImagen, 'https://img.test/azul.jpg');
      expect(azul.cloudinaryPublicId, 'productos/azul');
      expect(azul.filas.map((f) => f.etiqueta), ['S', 'M', 'L']);
      expect(azul.filas.map((f) => f.precioCentavos), [3500, 3500, 3800]);
      expect(azul.filas.map((f) => f.stock), [4, 6, 2]);
    });

    test('la fila conserva el tamaño real cuando lo tiene', () {
      final botella = _polo().copyWith(
        modelos: const [
          ModeloProducto(
            id: 'inca',
            nombre: 'Inca Kola',
            filas: [
              FilaVenta(
                id: 'a',
                etiqueta: '500 ml',
                precioCentavos: 250,
                stock: 24,
                formatoValorBase: 500,
                formatoFamilia: FamiliaUnidad.volumen,
                formatoUnidad: 'ml',
              ),
            ],
          ),
        ],
      );

      final leido = ProductoFirestoreMapper.desdeFirestore(
        'p1',
        ProductoFirestoreMapper.paraFirestore(botella),
      )!;

      final fila = leido.modelos.single.filas.single;
      expect(fila.formatoValorBase, 500);
      expect(fila.formatoFamilia, FamiliaUnidad.volumen);
      expect(fila.formatoUnidad, 'ml');
    });

    test('una fila por medida guarda su stock en unidad base', () {
      final queso = Producto(
        id: 'q1',
        negocioId: 'n1',
        nombre: 'Queso',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 1800,
        stockBase: 6500,
        tituloModelos: 'Tipo',
        modelos: const [
          ModeloProducto(
            id: 'fresco',
            nombre: 'Fresco',
            filas: [FilaVenta(id: 'f', precioCentavos: 1800, stockBase: 4000)],
          ),
          ModeloProducto(
            id: 'andino',
            nombre: 'Andino',
            filas: [FilaVenta(id: 'f', precioCentavos: 2400, stockBase: 2500)],
          ),
        ],
      );

      final leido = ProductoFirestoreMapper.desdeFirestore(
        'q1',
        ProductoFirestoreMapper.paraFirestore(queso),
      )!;

      expect(leido.modelos.map((m) => m.filas.single.stockBase), [4000, 2500]);
      expect(leido.modelos.map((m) => m.filas.single.precioCentavos), [
        1800,
        2400,
      ]);
    });
  });

  group('productos sin modelos', () {
    test('un producto simple se lee sin modelos ni títulos', () {
      final leido = ProductoFirestoreMapper.desdeFirestore('p', {
        'negocioId': 'n1',
        'nombre': 'Café',
        'precio': 5.0,
        'stock': 3,
      })!;

      expect(leido.tieneModelos, isFalse);
      expect(leido.modelos, isEmpty);
      expect(leido.tituloModelos, isEmpty);
      expect(leido.tituloFilas, isEmpty);
    });

    test('un producto simple se escribe con modelos vacíos', () {
      final datos = ProductoFirestoreMapper.paraFirestore(
        Producto(negocioId: 'n1', nombre: 'Café'),
      );
      expect(datos['modelos'], isEmpty);
      expect(datos['tituloModelos'], '');
    });
  });

  group('lectura defensiva', () {
    test('lo que no se entiende se ignora', () {
      final modelos = EstructuraProductoMapper.modelosDesde([
        'texto suelto',
        {'id': 'a', 'nombre': 'Azul', 'filas': 'no es una lista'},
        {
          'nombre': 'Rojo',
          'filas': [
            {'etiqueta': 'M', 'precioCentavos': 100, 'stock': 3.0},
            5,
          ],
        },
      ]);

      expect(modelos, hasLength(2));
      expect(modelos.first.filas, isEmpty);
      // Sin id se genera uno estable por posición.
      expect(modelos.last.id, 'm2');
      expect(modelos.last.filas.single.id, 'f0');
      expect(modelos.last.filas.single.stock, 3);
    });

    test('un valor que no es lista da vacío', () {
      expect(EstructuraProductoMapper.modelosDesde(null), isEmpty);
      expect(EstructuraProductoMapper.modelosDesde('x'), isEmpty);
    });
  });

  group('vista legacy con modelos (lo que lee la tienda actual)', () {
    test('precio "desde" y stock total', () {
      final datos = ProductoFirestoreMapper.paraFirestore(_polo());
      expect(datos['precio'], 35.0);
      expect(datos['stock'], 12);
    });

    test('los tamaños distintos de las filas se listan como fracciones', () {
      final botella = _polo().copyWith(
        presentacionId: 'botella',
        modelos: const [
          ModeloProducto(
            id: 'm1',
            nombre: 'Inca',
            filas: [
              FilaVenta(
                id: 'a',
                etiqueta: '500 ml',
                formatoValorBase: 500,
                formatoFamilia: FamiliaUnidad.volumen,
                formatoUnidad: 'ml',
              ),
              FilaVenta(
                id: 'b',
                etiqueta: '1 L',
                formatoValorBase: 1000,
                formatoFamilia: FamiliaUnidad.volumen,
                formatoUnidad: 'L',
              ),
            ],
          ),
          ModeloProducto(
            id: 'm2',
            nombre: 'Coca',
            filas: [
              FilaVenta(
                id: 'a',
                etiqueta: '500 ml',
                formatoValorBase: 500,
                formatoFamilia: FamiliaUnidad.volumen,
                formatoUnidad: 'ml',
              ),
            ],
          ),
        ],
      );

      final datos = ProductoFirestoreMapper.paraFirestore(botella);
      expect(datos['fraccionesSeleccionadas'], ['500 ml', '1 L']);
      expect(datos['unidadMedidaNombre'], 'Botella');
    });

    test('por medida el stock legacy es el total, con piso en la unidad', () {
      final queso = Producto(
        negocioId: 'n1',
        nombre: 'Queso',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        cantidadReferenciaBase: 1000,
        precioCentavos: 1800,
        stockBase: 6500,
        modelos: const [
          ModeloProducto(
            id: 'a',
            filas: [FilaVenta(id: 'f', precioCentavos: 1800, stockBase: 6500)],
          ),
        ],
      );

      final datos = ProductoFirestoreMapper.paraFirestore(queso);
      expect(datos['stock'], 6);
      expect(datos['precio'], 18.0);
    });
  });
}
