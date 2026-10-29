import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/sugerencias_modelos.dart';
import 'package:mobile/features/productos/application/services/validador_modelos.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/formulario_modelos_controller.dart';

FormularioModelosController _nuevo() =>
    FormularioModelosController(sugerencia: SugerenciasModelos.de('Ropa'));

String? _falta(
  FormularioModelosController c, {
  bool porMedida = false,
  bool infinito = false,
}) => c.queFalta(
  porMedida: porMedida,
  stockInfinito: infinito,
  factorStock: porMedida ? 1000 : 1,
  unidadBase: porMedida ? 'g' : '',
);

void _foto(ModeloEditable modelo) {
  modelo.fotoNuevaBytes = Uint8List.fromList([1, 2, 3]);
}

void _llenar(
  FilaEditable fila, {
  String etiqueta = '',
  String precio = '',
  String stock = '',
}) {
  fila.etiquetaCtrl.text = etiqueta;
  fila.precioCtrl.text = precio;
  fila.stockCtrl.text = stock;
}

void main() {
  late FormularioModelosController c;

  setUp(() => c = _nuevo());
  tearDown(() => c.dispose());

  group('activar', () {
    test('al decir Sí aparece el primer modelo con una fila vacía', () {
      expect(c.usa, isFalse);
      expect(c.modelos, isEmpty);

      c.activar(true, porMedida: false);

      expect(c.usa, isTrue);
      expect(c.modelos, hasLength(1));
      expect(c.modelos.single.filas, hasLength(1));
    });

    test('decir No y volver a Sí no duplica el modelo', () {
      c
        ..activar(true, porMedida: false)
        ..activar(false, porMedida: false)
        ..activar(true, porMedida: false);

      expect(c.modelos, hasLength(1));
    });

    test('el título de las filas parte del que sugiere el rubro', () {
      expect(c.tituloFilas, 'Talla');
    });
  });

  group('«Falta» sigue el orden de la pantalla', () {
    test('sin usar modelos no falta nada', () {
      expect(_falta(c), isNull);
    });

    test(
      'primero la palabra, después el nombre, la fila, el precio y el stock',
      () {
        c.activar(true, porMedida: false);
        expect(_falta(c), 'Falta: cómo se llama lo que cambia');

        c.tituloCtrl.text = 'Color';
        expect(_falta(c), 'Falta: nombre del color');

        final azul = c.modelos.single..nombreCtrl.text = 'Azul';

        expect(_falta(c), 'Falta: foto de Azul');

        _foto(azul);
        expect(_falta(c), 'Falta: nombre de talla de Azul');

        azul.filas.single.etiquetaCtrl.text = 'S';
        expect(_falta(c), 'Falta: precio de Azul · S');

        azul.filas.single.precioCtrl.text = '35';
        expect(_falta(c), 'Falta: stock de Azul · S');

        azul.filas.single.stockCtrl.text = '4';
        expect(_falta(c), isNull);
      },
    );

    test('un modelo sin filas pide una', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _foto(azul);
      c.quitarFila(azul.id, azul.filas.single.id);

      expect(_falta(c), 'Falta: talla de Azul');
    });

    test('un stock mal escrito dice Revisa y no Falta', () {
      c
        ..activar(true, porMedida: true)
        ..tituloCtrl.text = 'Tipo';
      final fresco = c.modelos.single..nombreCtrl.text = 'Fresco';
      _foto(fresco);
      _llenar(fresco.filas.single, precio: '18', stock: '0.000');

      expect(_falta(c, porMedida: true), 'Revisa: stock de Fresco');
    });

    test('con stock infinito no pide stock', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _foto(azul);
      _llenar(azul.filas.single, etiqueta: 'S', precio: '35');

      expect(_falta(c), 'Falta: stock de Azul · S');
      expect(_falta(c, infinito: true), isNull);
    });

    test('un precio en cero se revisa', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _foto(azul);
      _llenar(azul.filas.single, etiqueta: 'S', precio: '0', stock: '1');

      expect(_falta(c), 'Revisa: precio de Azul · S');
    });
  });

  group('acciones', () {
    test('un modelo nuevo copia las filas del primero con el stock vacío', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _foto(azul);
      _llenar(azul.filas.single, etiqueta: 'S', precio: '35', stock: '4');
      c.agregarFila(azul.id);
      _llenar(azul.filas.last, etiqueta: 'M', precio: '36', stock: '6');

      c.agregarModelo(porMedida: false);
      final rojo = c.modelos.last;

      expect(rojo.filas.map((f) => f.etiquetaCtrl.text), ['S', 'M']);
      expect(rojo.filas.map((f) => f.precioCtrl.text), ['35', '36']);
      expect(rojo.filas.map((f) => f.stockCtrl.text), ['', '']);
      expect(rojo.id, isNot(azul.id));
      expect(rojo.filas.first.id, isNot(azul.filas.first.id));
    });

    test('por medida el modelo nuevo copia solo una fila', () {
      c.activar(true, porMedida: true);
      final fresco = c.modelos.single;
      _llenar(fresco.filas.single, precio: '18', stock: '4');

      c.agregarModelo(porMedida: true);

      expect(c.modelos.last.filas, hasLength(1));
      expect(c.modelos.last.filas.single.precioCtrl.text, '18');
    });

    test('mismo precio a todas usa el de la primera fila', () {
      c.activar(true, porMedida: false);
      final azul = c.modelos.single;
      _llenar(azul.filas.single, etiqueta: 'S', precio: '35');
      c
        ..agregarFila(azul.id)
        ..agregarFila(azul.id);
      azul.filas[1].precioCtrl.text = '40';
      azul.filas[2].precioCtrl.text = '';

      c.mismoPrecio(azul.id);

      expect(azul.filas.map((f) => f.precioCtrl.text), ['35', '35', '35']);
    });

    test('quitar un modelo lo saca de la lista', () {
      c.activar(true, porMedida: false);
      c.agregarModelo(porMedida: false);
      final primero = c.modelos.first;

      c.quitarModelo(primero.id);

      expect(c.modelos, hasLength(1));
      expect(c.modelos.single.id, isNot(primero.id));
    });

    test('no pasa de 30 modelos ni de 20 filas', () {
      c.activar(true, porMedida: false);
      while (c.puedeAgregarModelo) {
        c.agregarModelo(porMedida: false);
      }
      expect(c.modelos, hasLength(ValidadorModelos.maxModelos));
      c.agregarModelo(porMedida: false);
      expect(c.modelos, hasLength(ValidadorModelos.maxModelos));

      final primero = c.modelos.first;
      while (c.puedeAgregarFila(primero)) {
        c.agregarFila(primero.id);
      }
      expect(primero.filas, hasLength(ValidadorModelos.maxFilas));
    });

    test('cambiar la palabra de las filas no toca los datos', () {
      c.activar(true, porMedida: false);
      c.cambiarTituloFilas('Número');
      expect(c.tituloFilas, 'Número');
      expect(c.modelos, hasLength(1));
    });
  });

  group('totales con candado', () {
    test('el total del modelo suma el stock de sus filas', () {
      c.activar(true, porMedida: false);
      final azul = c.modelos.single;
      c.agregarFila(azul.id);
      azul.filas[0].stockCtrl.text = '4';
      azul.filas[1].stockCtrl.text = '6';

      expect(
        c.totalDelModelo(
          azul,
          porMedida: false,
          factorStock: 1,
          unidadBase: '',
        ),
        '10',
      );
    });

    test('por medida el total se muestra en la unidad, con decimales', () {
      c.activar(true, porMedida: true);
      final fresco = c.modelos.single;
      fresco.filas.single.stockCtrl.text = '2.5';

      expect(
        c.totalDelModelo(
          fresco,
          porMedida: true,
          factorStock: 1000,
          unidadBase: 'g',
        ),
        '2.5',
      );
    });
  });

  group('construir', () {
    test('por presentación arma enteros: céntimos y unidades', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = ' Azul ';
      _foto(azul);
      _llenar(azul.filas.single, etiqueta: ' S ', precio: '35,5', stock: '4');

      final modelos = c.construir(
        porMedida: false,
        factorStock: 1,
        unidadBase: '',
      );

      expect(modelos.single.nombre, 'Azul');
      final fila = modelos.single.filas.single;
      expect(fila.etiqueta, 'S');
      expect(fila.precioCentavos, 3550);
      expect(fila.stock, 4);
      expect(fila.stockBase, isNull);
    });

    test('por medida guarda el stock en unidad base y sin etiqueta', () {
      c
        ..activar(true, porMedida: true)
        ..tituloCtrl.text = 'Tipo';
      final andino = c.modelos.single..nombreCtrl.text = 'Andino';
      _foto(andino);
      _llenar(andino.filas.single, precio: '24', stock: '2.5');

      final fila = c
          .construir(porMedida: true, factorStock: 1000, unidadBase: 'g')
          .single
          .filas
          .single;

      expect(fila.etiqueta, isEmpty);
      expect(fila.precioCentavos, 2400);
      expect(fila.stockBase, 2500);
      expect(fila.stock, 0);
    });

    test('sin usar modelos no arma ninguno', () {
      expect(
        c.construir(porMedida: false, factorStock: 1, unidadBase: ''),
        isEmpty,
      );
    });

    test('conserva el id de cada modelo y de cada fila', () {
      c.activar(true, porMedida: false);
      final azul = c.modelos.single;

      final modelos = c.construir(
        porMedida: false,
        factorStock: 1,
        unidadBase: '',
      );

      expect(modelos.single.id, azul.id);
      expect(modelos.single.filas.single.id, azul.filas.single.id);
    });
  });

  group('precargar', () {
    test('un producto guardado con modelos vuelve a la pantalla', () {
      final guardado = Producto(
        id: 'p1',
        negocioId: 'n1',
        nombre: 'Polo',
        modoVenta: ModoVenta.presentacion,
        presentacionId: 'unidad',
        tituloModelos: 'Color',
        tituloFilas: 'Número',
        modelos: const [
          ModeloProducto(
            id: 'azul',
            nombre: 'Azul',
            urlImagen: 'https://img.test/azul.jpg',
            filas: [
              FilaVenta(
                id: 's',
                etiqueta: '38',
                precioCentavos: 12050,
                stock: 3,
              ),
            ],
          ),
        ],
      );

      c.precargar(guardado, factorStock: 1);

      expect(c.usa, isTrue);
      expect(c.tituloCtrl.text, 'Color');
      expect(c.tituloFilas, 'Número');
      final azul = c.modelos.single;
      expect(azul.id, 'azul');
      expect(azul.urlImagen, 'https://img.test/azul.jpg');
      expect(azul.filas.single.etiquetaCtrl.text, '38');
      expect(azul.filas.single.precioCtrl.text, '120.50');
      expect(azul.filas.single.stockCtrl.text, '3');
    });

    test('por medida el stock vuelve en la unidad del producto', () {
      final queso = Producto(
        id: 'q1',
        negocioId: 'n1',
        nombre: 'Queso',
        modoVenta: ModoVenta.medida,
        medidaFamilia: FamiliaUnidad.peso,
        medidaUnidad: 'kg',
        tituloModelos: 'Tipo',
        modelos: const [
          ModeloProducto(
            id: 'andino',
            nombre: 'Andino',
            filas: [FilaVenta(id: 'f', precioCentavos: 2400, stockBase: 2500)],
          ),
        ],
      );

      c.precargar(queso, factorStock: 1000);

      expect(c.modelos.single.filas.single.stockCtrl.text, '2.5');
    });

    test('un producto sin modelos no activa nada', () {
      c.precargar(Producto(negocioId: 'n1', nombre: 'Café'), factorStock: 1);

      expect(c.usa, isFalse);
      expect(c.modelos, isEmpty);
    });
  });
}
