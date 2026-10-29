import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/sugerencias_modelos.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
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

  group('la foto de cada modelo es obligatoria', () {
    test('sin foto no se puede guardar, aunque lo demás esté completo', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _llenar(azul.filas.single, etiqueta: 'S', precio: '35', stock: '4');

      expect(_falta(c), 'Falta: foto de Azul');
      _foto(azul);
      expect(_falta(c), isNull);
    });

    test('una foto ya guardada cuenta', () {
      final guardado = Producto(
        id: 'p1',
        negocioId: 'n1',
        nombre: 'Polo',
        modoVenta: ModoVenta.presentacion,
        presentacionId: 'unidad',
        tituloModelos: 'Color',
        modelos: const [
          ModeloProducto(
            id: 'azul',
            nombre: 'Azul',
            urlImagen: 'https://img.test/azul.jpg',
            filas: [
              FilaVenta(id: 's', etiqueta: 'S', precioCentavos: 3500, stock: 1),
            ],
          ),
        ],
      );

      c.precargar(guardado, factorStock: 1);

      expect(c.modelos.single.tieneFoto, isTrue);
      expect(_falta(c), isNull);
    });

    test('cada modelo pide la suya', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _foto(azul);
      _llenar(azul.filas.single, etiqueta: 'S', precio: '35', stock: '4');
      c.agregarModelo(porMedida: false);
      final rojo = c.modelos.last..nombreCtrl.text = 'Rojo';
      rojo.filas.single.stockCtrl.text = '2';

      expect(_falta(c), 'Falta: foto de Rojo');
    });
  });

  group('avisos anti-duplicado', () {
    void armar() {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _foto(azul);
      _llenar(azul.filas.single, etiqueta: 'M', precio: '35', stock: '3');
      c.agregarFila(azul.id);
      _llenar(azul.filas.last, etiqueta: 'm', precio: '35', stock: '2');
    }

    test('la misma fila dos veces en un modelo avisa y bloquea', () {
      armar();

      expect(
        c.avisoRepetido(c.modelos.single),
        'Ya tienes «Azul · m» dos veces: junta el stock o cambia el nombre.',
      );
      expect(_falta(c), startsWith('Revisa:'));
    });

    test('dos modelos con el mismo nombre bloquean', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _foto(azul);
      _llenar(azul.filas.single, etiqueta: 'S', precio: '35', stock: '3');
      c.agregarModelo(porMedida: false);
      final otro = c.modelos.last..nombreCtrl.text = 'azul';
      _foto(otro);
      otro.filas.single.stockCtrl.text = '1';

      expect(_falta(c), 'Revisa: «azul» está repetido');
    });

    test('la misma talla en dos modelos distintos es normal', () {
      c
        ..activar(true, porMedida: false)
        ..tituloCtrl.text = 'Color';
      final azul = c.modelos.single..nombreCtrl.text = 'Azul';
      _foto(azul);
      _llenar(azul.filas.single, etiqueta: 'M', precio: '35', stock: '3');
      c.agregarModelo(porMedida: false);
      final rojo = c.modelos.last..nombreCtrl.text = 'Rojo';
      _foto(rojo);
      rojo.filas.single.stockCtrl.text = '5';

      expect(c.avisoRepetido(azul), isEmpty);
      expect(_falta(c), isNull);
    });
  });
}
