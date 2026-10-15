import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/constructor_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

DatosFormularioProducto _datos({
  Producto? anterior,
  ModoVenta? modo,
  bool medidaCompleta = false,
  bool presentacionCompleta = false,
  bool esStockInfinito = false,
  int? stockMedidaBase,
  int? precioVisibleCentavos,
}) => DatosFormularioProducto(
  anterior: anterior,
  nombre: 'Arroz',
  descripcion: '',
  categoria: 'Abarrotes',
  tieneDelivery: true,
  urlImagen: '',
  esStockInfinito: esStockInfinito,
  modo: modo,
  medidaCompleta: medidaCompleta,
  medidaFamilia: FamiliaUnidad.peso,
  medidaUnidad: 'kg',
  referenciaBase: 1000,
  precioMedidaCentavos: 450,
  stockMedidaBase: stockMedidaBase,
  presentacionCompleta: presentacionCompleta,
  presentacionId: 'botella',
  formatoValorBase: 500,
  formatoFamilia: 'volumen',
  formatoUnidad: 'ml',
  precioPresentacionCentavos: 250,
  stockPresentacion: 40,
  precioVisibleCentavos: precioVisibleCentavos,
);

void main() {
  test('medida completa arma un producto por medida en unidad base', () {
    final producto = ConstructorProducto.construir(
      _datos(
        modo: ModoVenta.medida,
        medidaCompleta: true,
        stockMedidaBase: 25000,
      ),
    );

    expect(producto.modoVenta, ModoVenta.medida);
    expect(producto.medidaFamilia, FamiliaUnidad.peso);
    expect(producto.medidaUnidad, 'kg');
    expect(producto.cantidadReferenciaBase, 1000);
    expect(producto.precioCentavos, 450);
    expect(producto.stockBase, 25000);
  });

  test('medida con stock infinito no guarda stockBase', () {
    final producto = ConstructorProducto.construir(
      _datos(
        modo: ModoVenta.medida,
        medidaCompleta: true,
        esStockInfinito: true,
      ),
    );

    expect(producto.esStockInfinito, isTrue);
    expect(producto.stockBase, isNull);
  });

  test('presentación completa arma un producto por presentación', () {
    final producto = ConstructorProducto.construir(
      _datos(modo: ModoVenta.presentacion, presentacionCompleta: true),
    );

    expect(producto.modoVenta, ModoVenta.presentacion);
    expect(producto.presentacionId, 'botella');
    expect(producto.formatoValorBase, 500);
    expect(producto.formatoFamilia, FamiliaUnidad.volumen);
    expect(producto.formatoUnidad, 'ml');
    expect(producto.precioCentavos, 250);
    expect(producto.stock, 40);
  });

  test('legacy sin migrar conserva su unidad, fracciones y stock', () {
    final anterior = Producto(
      id: 'p1',
      negocioId: 'n1',
      nombre: 'Arroz',
      stock: 7,
      etiquetaUnidad: 'Saco',
      fraccionesSeleccionadas: const ['1/2'],
      precioCentavos: 900,
    );

    final producto = ConstructorProducto.construir(
      _datos(
        anterior: anterior,
        modo: ModoVenta.presentacion,
        precioVisibleCentavos: 950,
      ),
    );

    expect(producto.id, 'p1');
    expect(producto.negocioId, 'n1');
    expect(producto.modoVenta, ModoVenta.presentacion);
    expect(producto.presentacionId, isEmpty);
    expect(producto.etiquetaUnidad, 'Saco');
    expect(producto.fraccionesSeleccionadas, ['1/2']);
    expect(producto.stock, 7);
    expect(producto.precioCentavos, 950);
  });

  test('legacy sin precio escrito conserva el precio anterior', () {
    final anterior = Producto(
      negocioId: 'n1',
      nombre: 'Arroz',
      precioCentavos: 900,
    );

    final producto = ConstructorProducto.construir(_datos(anterior: anterior));

    expect(producto.precioCentavos, 900);
  });
}
