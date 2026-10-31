import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/sugerencias_combo.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/formulario_combo_controller.dart';

Producto _p(
  String id,
  int precio,
  int stock, {
  List<ParteCombo> partes = const [],
  bool medida = false,
}) => Producto(
  id: id,
  negocioId: 'n',
  nombre: id,
  precioCentavos: precio,
  stock: stock,
  partes: partes,
  modoVenta: medida ? ModoVenta.medida : ModoVenta.presentacion,
  medidaFamilia: medida ? FamiliaUnidad.peso : null,
);

ParteCombo _parte(String id, [int cantidad = 1]) =>
    ParteCombo(productoId: id, cantidad: cantidad, nombre: id);

void main() {
  late FormularioComboController combo;

  setUp(() {
    combo = FormularioComboController(
      nombre: SugerenciasCombo.de('Restaurante'),
      idPropio: '',
      productos: [
        _p('pollo', 1800, 10),
        _p('papas', 600, 7),
        _p('gaseosa', 400, 9),
        _p('queso', 2400, 5, medida: true),
        _p('combo-viejo', 3000, 0, partes: [_parte('pollo')]),
      ],
    )..activar(true);
  });
  tearDown(() => combo.dispose());

  test(
    'solo se pueden elegir productos que se cuentan, sin combos ni él mismo',
    () {
      final propio = FormularioComboController(
        nombre: SugerenciasCombo.de('Ropa'),
        idPropio: 'pollo',
        productos: [
          _p('pollo', 1, 1),
          _p('papas', 1, 1),
          _p('queso', 1, 1, medida: true),
        ],
      );
      addTearDown(propio.dispose);

      expect(combo.elegibles.map((p) => p.id), ['pollo', 'papas', 'gaseosa']);
      expect(propio.elegibles.map((p) => p.id), ['papas']);
    },
  );

  test('el precio arranca con la suma y se mueve con las partes', () {
    combo.agregar(_parte('pollo'));
    expect(combo.precioCtrl.text, '18.00');

    combo.agregar(_parte('papas'));
    combo.agregar(_parte('gaseosa', 2));
    expect(combo.precioCtrl.text, '32.00');
    expect(combo.resultado.sumaCentavos, 3200);
  });

  test(
    'si el encargado escribe su precio, no se mueve solo y se ve el ahorro',
    () {
      combo.agregar(_parte('pollo'));
      combo.agregar(_parte('papas'));
      combo.agregar(_parte('gaseosa', 2));

      combo.precioCtrl.text = '28';
      combo.trasCambioPrecio();
      combo.cambiarCantidad(0, 1);

      expect(combo.precioCtrl.text, '28');
      expect(combo.precioCentavos, 2800);
      expect(combo.resultado.sumaCentavos, 5000);
      expect(combo.ahorroCentavos, 2200);
    },
  );

  test('«Usar la suma» y precio vacío vuelven a proponer la suma', () {
    combo.agregar(_parte('pollo'));
    combo.agregar(_parte('papas'));
    combo.precioCtrl.text = '20';
    combo.trasCambioPrecio();

    combo.usarLaSuma();
    expect(combo.precioCtrl.text, '24.00');

    combo.precioCtrl.text = '';
    combo.trasCambioPrecio();
    expect(combo.precioCtrl.text, '24.00');
  });

  test('si el precio es mayor que la suma no hay ahorro', () {
    combo.agregar(_parte('pollo'));
    combo.agregar(_parte('papas'));
    combo.precioCtrl.text = '30';
    combo.trasCambioPrecio();

    expect(combo.ahorroCentavos, isNull);
  });

  test('la misma parte no se repite: se suma su cantidad', () {
    combo.agregar(_parte('pollo'));
    combo.agregar(_parte('pollo', 2));

    expect(combo.partes, hasLength(1));
    expect(combo.partes.single.cantidad, 3);
  });

  test('máximo de partes y cantidad mínima 1', () {
    for (var i = 0; i < ParteCombo.maximo + 2; i++) {
      combo.agregar(_parte('p$i'));
    }
    expect(combo.partes, hasLength(ParteCombo.maximo));
    expect(combo.puedeAgregar, isFalse);

    combo.cambiarCantidad(0, -1);
    expect(combo.partes.first.cantidad, 1);
  });

  test('avisos: faltan partes y falta precio, con la palabra del rubro', () {
    expect(combo.queFalta(), 'Falta: al menos 2 productos en el combo');

    combo.agregar(_parte('pollo'));
    combo.agregar(_parte('papas'));
    combo.precioCtrl.text = '';
    combo.trasCambioPrecio();
    combo.precioCtrl.text = '';
    expect(combo.queFalta(), 'Falta: precio del combo');

    combo.precioCtrl.text = '0';
    expect(combo.queFalta(), 'Revisa: precio del combo');

    combo.precioCtrl.text = '25';
    expect(combo.queFalta(), isNull);
  });

  test('avisa si las partes cambiaron desde que se fijó el precio', () {
    final guardado = Producto(
      id: 'c1',
      negocioId: 'n',
      nombre: 'Combo',
      precioCentavos: 2800,
      sumaPartesCentavos: 3200,
      partes: [_parte('pollo'), _parte('papas')],
    );
    final editado = FormularioComboController(
      nombre: SugerenciasCombo.de('Restaurante'),
      idPropio: 'c1',
      productos: [_p('pollo', 2000, 10), _p('papas', 600, 7)],
    )..precargar(guardado);
    addTearDown(editado.dispose);

    expect(editado.usa, isTrue);
    expect(editado.precioCtrl.text, '28.00');
    expect(
      editado.avisoPartesCambiaron,
      'Las partes ahora suman S/ 26.00 (antes S/ 32.00).',
    );
  });

  test('con «No» no se guarda nada', () {
    combo.agregar(_parte('pollo'));
    combo.activar(false);

    expect(combo.construir(), isEmpty);
    expect(combo.queFalta(), isNull);
    expect(combo.sumaParaGuardar, 0);
  });

  test('la palabra de cada rubro', () {
    expect(SugerenciasCombo.de('Restaurante').palabra, 'combo');
    expect(SugerenciasCombo.de('Bodega').palabra, 'combo');
    expect(SugerenciasCombo.de('Ropa').palabra, 'conjunto');
    expect(
      SugerenciasCombo.de('Accesorios y regalos').palabra,
      'set de regalo',
    );
    expect(SugerenciasCombo.de('Belleza y cuidado personal').palabra, 'kit');
    expect(SugerenciasCombo.de('Otros').palabra, 'pack');
    expect(SugerenciasCombo.de('Kit').capitalizada, 'Pack');
    expect(
      SugerenciasCombo.de('Belleza y cuidado personal').capitalizada,
      'Kit',
    );
  });
}
