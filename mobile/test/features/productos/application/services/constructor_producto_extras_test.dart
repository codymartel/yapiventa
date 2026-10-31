import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/constructor_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';

const _extras = [
  ExtraProducto(id: 'e1', nombre: 'Con ají'),
  ExtraProducto(id: 'e2', nombre: 'Papas', precioCentavos: 600),
];

DatosFormularioProducto _datos({
  required ModoVenta modo,
  bool medidaCompleta = false,
  bool presentacionCompleta = true,
  List<ModeloProducto> modelos = const [],
}) => DatosFormularioProducto(
  anterior: null,
  nombre: 'Pollo',
  descripcion: '',
  categoria: 'Platos',
  tieneDelivery: true,
  urlImagen: '',
  esStockInfinito: false,
  modo: modo,
  medidaCompleta: medidaCompleta,
  medidaFamilia: FamiliaUnidad.peso,
  medidaUnidad: 'kg',
  referenciaBase: 1000,
  precioMedidaCentavos: 1800,
  stockMedidaBase: 5000,
  presentacionCompleta: presentacionCompleta,
  presentacionId: 'unidad',
  presentacionNombre: 'Unidad',
  formatoValorBase: 1,
  formatoFamilia: 'conteo',
  formatoUnidad: 'unidad',
  precioPresentacionCentavos: 1800,
  stockPresentacion: 10,
  tituloModelos: modelos.isEmpty ? '' : 'Color',
  tituloFilas: modelos.isEmpty ? '' : 'Talla',
  modelos: modelos,
  extras: _extras,
);

void main() {
  test('por presentación simple: el producto lleva sus extras', () {
    final producto = ConstructorProducto.construir(
      _datos(modo: ModoVenta.presentacion),
    );

    expect(producto.extras, hasLength(2));
    expect(producto.extras[1].precioCentavos, 600);
  });

  test('con variables: los extras son del producto entero', () {
    final producto = ConstructorProducto.construir(
      _datos(
        modo: ModoVenta.presentacion,
        modelos: const [
          ModeloProducto(
            id: 'azul',
            nombre: 'Azul',
            filas: [
              FilaVenta(id: 'm', etiqueta: 'M', precioCentavos: 1800, stock: 3),
            ],
          ),
        ],
      ),
    );

    expect(producto.modelos, hasLength(1));
    expect(producto.extras, hasLength(2));
  });

  test('un producto antiguo sin migrar conserva sus extras', () {
    final producto = ConstructorProducto.construir(
      _datos(modo: ModoVenta.presentacion, presentacionCompleta: false),
    );

    expect(producto.extras, hasLength(2));
  });

  test('por medida no guarda extras', () {
    final producto = ConstructorProducto.construir(
      _datos(modo: ModoVenta.medida, medidaCompleta: true),
    );

    expect(producto.esPorMedida, isTrue);
    expect(producto.extras, isEmpty);
  });
}
