import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/constructor_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';

const _modelos = [
  ModeloProducto(
    id: 'azul',
    nombre: 'Azul',
    filas: [
      FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 4),
      FilaVenta(id: 'm', etiqueta: 'M', precioCentavos: 3500, stock: 6),
    ],
  ),
  ModeloProducto(
    id: 'rojo',
    nombre: 'Rojo',
    filas: [FilaVenta(id: 'l', etiqueta: 'L', precioCentavos: 3200, stock: 5)],
  ),
];

DatosFormularioProducto _datos({
  required ModoVenta modo,
  List<ModeloProducto> modelos = _modelos,
  String presentacionId = 'unidad',
  bool medidaCompleta = false,
  bool esStockInfinito = false,
}) => DatosFormularioProducto(
  anterior: null,
  nombre: 'Polo básico',
  descripcion: '',
  categoria: 'Hombre',
  tieneDelivery: true,
  urlImagen: '',
  esStockInfinito: esStockInfinito,
  modo: modo,
  medidaCompleta: medidaCompleta,
  medidaFamilia: FamiliaUnidad.peso,
  medidaUnidad: 'kg',
  referenciaBase: 1000,
  presentacionCompleta: false,
  presentacionId: presentacionId,
  tituloModelos: 'Color',
  tituloFilas: 'Talla',
  presentacionNombre: 'Jaba',
  modelos: modelos,
);

void main() {
  group('por presentación con modelos', () {
    test('el precio desde y el stock total se calculan de las filas', () {
      final producto = ConstructorProducto.construir(
        _datos(modo: ModoVenta.presentacion),
      );

      expect(producto.modoVenta, ModoVenta.presentacion);
      expect(producto.presentacionId, 'unidad');
      expect(producto.presentacionNombre, 'Jaba');
      expect(producto.precioCentavos, 3200);
      expect(producto.stock, 15);
      expect(producto.tituloModelos, 'Color');
      expect(producto.tituloFilas, 'Talla');
      expect(producto.modelos, hasLength(2));
    });

    test('no exige el formato del producto: cada fila lleva el suyo', () {
      final producto = ConstructorProducto.construir(
        _datos(modo: ModoVenta.presentacion, presentacionId: 'botella'),
      );

      expect(producto.presentacionId, 'botella');
      expect(producto.formatoValorBase, 0);
      expect(producto.tieneModelos, isTrue);
    });

    test('sin presentación elegida no se arma como producto con modelos', () {
      final producto = ConstructorProducto.construir(
        _datos(modo: ModoVenta.presentacion, presentacionId: ''),
      );

      expect(producto.tieneModelos, isFalse);
    });
  });

  group('por medida con modelos', () {
    const queso = [
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
    ];

    test('el stock base total y el precio desde salen de los modelos', () {
      final producto = ConstructorProducto.construir(
        _datos(modo: ModoVenta.medida, medidaCompleta: true, modelos: queso),
      );

      expect(producto.modoVenta, ModoVenta.medida);
      expect(producto.cantidadReferenciaBase, 1000);
      expect(producto.precioCentavos, 1800);
      expect(producto.stockBase, 6500);
      expect(producto.modelos, hasLength(2));
    });

    test('con stock infinito no guarda stock base', () {
      final producto = ConstructorProducto.construir(
        _datos(
          modo: ModoVenta.medida,
          medidaCompleta: true,
          modelos: queso,
          esStockInfinito: true,
        ),
      );

      expect(producto.stockBase, isNull);
      expect(producto.esStockInfinito, isTrue);
    });
  });

  test('sin modelos el producto se arma como siempre', () {
    final producto = ConstructorProducto.construir(
      _datos(modo: ModoVenta.presentacion, modelos: const []),
    );

    expect(producto.tieneModelos, isFalse);
  });
}
