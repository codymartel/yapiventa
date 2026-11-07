import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/campos_catalogo_producto.dart';
import 'package:mobile/features/productos/data/mappers/producto_firestore_mapper.dart';

import '../../../pedidos/helpers/pedidos_de_prueba.dart';

void main() {
  group('nombreBusqueda', () {
    test('minúsculas, sin tildes y la ñ como n', () {
      expect(CamposCatalogoProducto.nombreBusqueda('Piña Dulce'), 'pina dulce');
      expect(
        CamposCatalogoProducto.nombreBusqueda('CAFÉ ÁLVAREZ'),
        'cafe alvarez',
      );
      expect(CamposCatalogoProducto.nombreBusqueda('Pingüino'), 'pinguino');
    });

    test('junta los espacios y recorta los bordes', () {
      expect(
        CamposCatalogoProducto.nombreBusqueda('  Queso   andino \n'),
        'queso andino',
      );
    });

    test('vacío o solo espacios queda vacío', () {
      expect(CamposCatalogoProducto.nombreBusqueda(''), '');
      expect(CamposCatalogoProducto.nombreBusqueda('   '), '');
    });

    test('no pasa de 60 letras', () {
      final largo = CamposCatalogoProducto.nombreBusqueda('a' * 100);
      expect(largo.length, CamposCatalogoProducto.maximoLetras);
    });

    test('lo que escribe el cajero y lo guardado se parecen', () {
      final guardado = CamposCatalogoProducto.nombreBusqueda('Gaseosa Inca');
      final escrito = CamposCatalogoProducto.nombreBusqueda('GASEO');
      expect(guardado.startsWith(escrito), isTrue);
    });
  });

  group('tipoCaja', () {
    test('un producto que se cuenta es simple', () {
      expect(CamposCatalogoProducto.tipoCaja(productoSimple()), 'simple');
    });

    test('por peso, volumen, longitud o área es medida', () {
      expect(CamposCatalogoProducto.tipoCaja(quesoPorMedida()), 'medida');
    });

    test('con modelos es variable', () {
      expect(CamposCatalogoProducto.tipoCaja(poloConModelos()), 'variable');
    });

    test('con partes es combo', () {
      expect(CamposCatalogoProducto.tipoCaja(comboGaseosaYPapas()), 'combo');
    });
  });

  test('el mapper guarda los dos campos calculados', () {
    final datos = ProductoFirestoreMapper.paraFirestore(
      productoSimple(nombre: 'Piña Dulce'),
    );

    expect(datos['nombreBusqueda'], 'pina dulce');
    expect(datos['tipoCaja'], 'simple');
    expect(
      datos.containsKey('vendidos'),
      isFalse,
      reason: 'vendidos lo suben las ventas: editar no debe reiniciarlo',
    );
  });
}
