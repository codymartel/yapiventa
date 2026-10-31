import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/constructor_producto.dart';
import 'package:mobile/features/productos/application/services/textos_tarjeta_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

Producto _p(String id, String nombre, int precio, int stock) => Producto(
  id: id,
  negocioId: 'n',
  nombre: nombre,
  precioCentavos: precio,
  stock: stock,
);

void main() {
  const partes = [
    ParteCombo(productoId: 'pollo', cantidad: 1, nombre: 'Pollo ¼'),
    ParteCombo(productoId: 'papas', cantidad: 1, nombre: 'Papas'),
    ParteCombo(productoId: 'gaseosa', cantidad: 2, nombre: 'Gaseosa'),
  ];

  group('constructor: guardar un combo', () {
    final producto = ConstructorProducto.construir(
      const DatosFormularioProducto(
        anterior: null,
        nombre: 'Combo familiar',
        descripcion: '',
        categoria: 'Platos',
        tieneDelivery: true,
        urlImagen: '',
        esStockInfinito: false,
        modo: ModoVenta.presentacion,
        medidaCompleta: false,
        presentacionCompleta: false,
        partes: partes,
        precioComboCentavos: 2800,
        sumaPartesCentavos: 3200,
        extras: [ExtraProducto(id: 'e', nombre: 'Con ají')],
      ),
    );

    test('lleva su precio propio, sus partes y la suma de ese momento', () {
      expect(producto.esCombo, isTrue);
      expect(producto.precioCentavos, 2800);
      expect(producto.partes, hasLength(3));
      expect(producto.sumaPartesCentavos, 3200);
    });

    test('no tiene stock propio ni es infinito', () {
      expect(producto.stock, 0);
      expect(producto.esStockInfinito, isFalse);
    });

    test('se guarda como una unidad y conserva sus extras', () {
      expect(producto.presentacionId, 'unidad');
      expect(producto.modelos, isEmpty);
      expect(producto.extras.single.nombre, 'Con ají');
    });
  });

  group('tarjeta de la lista', () {
    final combo = Producto(
      id: 'c',
      negocioId: 'n',
      nombre: 'Combo familiar',
      precioCentavos: 2800,
      partes: partes,
    );
    final pollo = _p('pollo', 'Pollo ¼', 1800, 10);
    final papas = _p('papas', 'Papas', 600, 7);
    final gaseosa = _p('gaseosa', 'Gaseosa', 400, 9);

    test('el precio es el suyo, sin «/ unidad»', () {
      expect(TextosTarjetaProducto.precio(combo), 'S/ 28.00');
    });

    test('«Quedan 4 · limita: Gaseosa»', () {
      expect(
        TextosTarjetaProducto.stock(combo, conocidos: [pollo, papas, gaseosa]),
        'Quedan 4 · limita: Gaseosa',
      );
    });

    test('«Agotado · sin Papas»', () {
      expect(
        TextosTarjetaProducto.stock(
          combo,
          conocidos: [pollo, _p('papas', 'Papas', 600, 0), gaseosa],
        ),
        'Agotado · sin Papas',
      );
    });

    test('si no están cargadas las partes, no se inventa un número', () {
      expect(TextosTarjetaProducto.stock(combo, conocidos: [pollo]), '—');
    });

    test('«Kit · 3 productos»', () {
      expect(
        TextosTarjetaProducto.etiquetaCombo(combo, 'Kit'),
        'Kit · 3 productos',
      );
    });
  });
}
