import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/productos/application/services/sugerencias_extras.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';
import 'package:mobile/features/productos/presentation/providers/formulario_extras_controller.dart';

void main() {
  late FormularioExtrasController extras;

  setUp(() {
    extras = FormularioExtrasController(
      sugerencias: SugerenciasExtras.de('Restaurante'),
    )..activar(true);
  });
  tearDown(() => extras.dispose());

  void fila(String nombre, [String precio = '']) {
    extras.agregar();
    final f = extras.filas.last;
    f.nombreCtrl.text = nombre;
    f.precioCtrl.text = precio;
  }

  test('con «No» no se guarda nada aunque haya filas escritas', () {
    fila('Papas', '6');
    extras.activar(false);

    expect(extras.construir(), isEmpty);
    expect(extras.cantidad, 0);
    expect(extras.queFalta(), isNull);

    extras.activar(true);
    expect(extras.construir(), hasLength(1));
  });

  test('precio en céntimos enteros y vacío = gratis', () {
    fila('Con ají');
    fila('Papas', '6,50');

    final salida = extras.construir();
    expect(salida[0].precioCentavos, 0);
    expect(salida[1].precioCentavos, 650);
  });

  test('la fila totalmente vacía se ignora', () {
    extras.agregar();
    fila('Papas', '6');

    expect(extras.cantidad, 1);
    expect(extras.construir(), hasLength(1));
    expect(extras.queFalta(), isNull);
  });

  test('avisos: falta nombre, precio 0 o inválido y repetido', () {
    fila('', '5');
    expect(extras.queFalta(), 'Falta: nombre del extra');

    extras.filas.last.nombreCtrl.text = 'Papas';
    extras.filas.last.precioCtrl.text = '0';
    expect(extras.queFalta(), 'Revisa: precio de Papas');

    extras.filas.last.precioCtrl.text = '6';
    expect(extras.queFalta(), isNull);

    fila(' papas ');
    expect(extras.queFalta(), 'Revisa: «papas» está repetido');
  });

  test('máximo de extras', () {
    for (var i = 0; i < ExtraProducto.maximo + 3; i++) {
      extras.agregar();
    }

    expect(extras.filas, hasLength(ExtraProducto.maximo));
    expect(extras.puedeAgregar, isFalse);
  });

  test('tocar un extra sugerido lo agrega con su precio, una sola vez', () {
    final papas = SugerenciasExtras.de(
      'Restaurante',
    ).firstWhere((s) => s.nombre == 'Papas');

    extras.agregarSugerido(papas);
    extras.agregarSugerido(papas);

    expect(extras.filas, hasLength(1));
    expect(extras.construir().single.precioCentavos, 600);
    expect(
      extras.sugerenciasPendientes.map((s) => s.nombre),
      isNot(contains('Papas')),
    );
  });

  test('precarga de un producto con extras empieza en «Sí»', () {
    final nuevo = FormularioExtrasController(sugerencias: const []);
    addTearDown(nuevo.dispose);
    nuevo.precargar(
      Producto(
        negocioId: 'n',
        nombre: 'Pollo',
        extras: const [
          ExtraProducto(id: 'e1', nombre: 'Papas', precioCentavos: 600),
        ],
      ),
    );

    expect(nuevo.usa, isTrue);
    expect(nuevo.filas.single.precioCtrl.text, '6.00');
    expect(nuevo.construir().single.id, 'e1');
  });

  test('copiar y restaurar dejan los extras como estaban («Cancelar»)', () {
    fila('Papas', '6');
    final copia = extras.copiar();

    extras.agregar();
    extras.filas.first.nombreCtrl.text = 'Cambiado';
    extras.activar(false);
    extras.restaurar(copia);

    expect(extras.usa, isTrue);
    expect(extras.filas, hasLength(1));
    expect(extras.filas.single.nombreCtrl.text, 'Papas');
  });

  test('las sugerencias de cada rubro y las de Otros', () {
    expect(SugerenciasExtras.de('Ropa').single.nombre, 'Bordado');
    expect(SugerenciasExtras.de('Ropa').single.precioCentavos, 800);
    expect(SugerenciasExtras.de('Bodega').single.precioCentavos, 50);
    expect(SugerenciasExtras.de('Rubro raro').single.nombre, 'Mica');
  });
}
