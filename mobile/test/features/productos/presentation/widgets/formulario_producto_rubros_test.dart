import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/preset_venta_rubro.dart';
import 'package:mobile/features/productos/application/services/sugerencias_modelos.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/presentation/widgets/formulario/fila_modelo_producto.dart';
import 'package:mocktail/mocktail.dart';

import 'formulario_producto_helpers.dart';

/// Los 6 rubros del sistema, con sus presets REALES: ¿un vendedor de cada
/// rubro puede crear un producto con variables con cada una de sus
/// presentaciones?
void main() {
  setUpAll(() => registerFallbackValue(ProductoFake()));
  setUp(usarSelectorDeFotosFalso);

  ProductosProviderMock providerQueGuarda() {
    final provider = ProductosProviderMock();
    when(
      () => provider.crearProducto(
        any(),
        imagenBytes: any(named: 'imagenBytes'),
        nombreArchivo: any(named: 'nombreArchivo'),
        fotosModelos: any(named: 'fotosModelos'),
      ),
    ).thenAnswer((_) async => true);
    return provider;
  }

  String? falta(WidgetTester tester) {
    final texto = find.byKey(const Key('falta-para-guardar'));
    return texto.evaluate().isEmpty ? null : tester.widget<Text>(texto).data;
  }

  Future<void> escribir(
    WidgetTester tester,
    String etiqueta,
    String texto,
  ) async {
    await tester.enterText(campo(etiqueta).first, texto);
    await tester.pump();
  }

  final rubros = PresetsVenta.porRubro.keys.toList();

  test('hay 6 rubros', () => expect(rubros, hasLength(6)));

  for (final rubro in rubros) {
    final preset = PresetsVenta.obtener(rubro);
    final catalogo = CatalogoVentaPersistido.desdePreset(preset);
    final sugerencia = SugerenciasModelos.de(rubro);
    final activas = catalogo.presentaciones.where((p) => p.activa).toList();

    group(rubro, () {
      test('tiene palabras propias para nombrar lo que cambia', () {
        expect(sugerencia.palabras, isNotEmpty);
        expect(sugerencia.ejemplo, isNotEmpty);
      });

      for (final presentacion in activas) {
        testWidgets(
          'crea un producto con variables en «${presentacion.nombre}»',
          (tester) async {
            final provider = providerQueGuarda();
            await montar(
              tester,
              formulario(
                provider: provider,
                catalogoVenta: catalogo,
                rubro: rubro,
                categorias: preset.categorias,
              ),
            );
            final conFormatos = presentacion.formatos.length > 1;

            await escribir(
              tester,
              'Nombre del producto *',
              'Producto de prueba',
            );
            await elegirEnDropdown(
              tester,
              'Presentación *',
              presentacion.nombre,
            );
            await tester.tap(find.text('Sí'));
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(Key('sugerencia-${sugerencia.palabras.first}')),
            );
            await tester.pump();

            final palabra = sugerencia.palabras.first.toLowerCase();
            await escribir(tester, 'Nombre del $palabra *', 'Primero');
            if (conFormatos) {
              await elegirEnDropdown(
                tester,
                presentacion.nombre,
                FilaModeloProducto.textoFormato(presentacion.formatos.first),
              );
            } else {
              await escribir(tester, sugerencia.tituloFilas, 'Fila uno');
            }
            await escribir(tester, 'Precio S/', '10');
            await escribir(tester, 'Stock', '3');

            await ponerFotos(tester);
            expect(falta(tester), isNull, reason: 'debería poder guardarse');
            await tester.tap(
              find.widgetWithText(ElevatedButton, 'Guardar producto'),
            );
            await tester.pump();

            final producto = capturarProductoCreado(provider);
            expect(producto.presentacionId, presentacion.id);
            expect(producto.modelos, hasLength(1));
            expect(producto.tituloFilas, sugerencia.tituloFilas);
            expect(producto.precioCentavos, 1000);
            expect(producto.stock, 3);
            final fila = producto.modelos.single.filas.single;
            if (conFormatos) {
              expect(
                fila.formatoValorBase,
                presentacion.formatos.first.valorBase,
              );
            } else {
              expect(fila.formatoValorBase, 0);
            }
          },
        );
      }

      final medidasActivas = catalogo.medidas.where((m) => m.activa).toList();
      if (medidasActivas.isEmpty) {
        testWidgets('«Por medida» está apagado y dice dónde activarlo', (
          tester,
        ) async {
          await montar(
            tester,
            formulario(
              catalogoVenta: catalogo,
              rubro: rubro,
              categorias: preset.categorias,
            ),
          );

          expect(
            find.byKey(const Key('aviso-medida-inactiva')),
            findsOneWidget,
          );
        });
      } else {
        for (final medida in medidasActivas) {
          testWidgets(
            'crea un producto por medida con variables en «${medida.nombre}»',
            (tester) async {
              final provider = providerQueGuarda();
              await montar(
                tester,
                formulario(
                  provider: provider,
                  catalogoVenta: catalogo,
                  rubro: rubro,
                  categorias: preset.categorias,
                ),
              );

              await tester.tap(find.text('Lo peso'));
              await tester.pumpAndSettle();
              await escribir(tester, 'Nombre del producto *', 'A granel');
              if (medidasActivas.length > 1) {
                await elegirEnDropdown(tester, 'Qué mides *', medida.nombre);
              }
              await tester.tap(find.text('Sí'));
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(Key('sugerencia-${sugerencia.palabras.first}')),
              );
              await tester.pump();
              final palabra = sugerencia.palabras.first.toLowerCase();
              await escribir(tester, 'Nombre del $palabra *', 'Primero');
              await tester.enterText(
                find
                    .widgetWithText(
                      TextField,
                      'Precio S/ por 1 ${medida.unidadVisual!.nombre}',
                    )
                    .first,
                '12',
              );
              await tester.pump();
              await escribir(tester, 'Stock', '2');

              await ponerFotos(tester);
              expect(falta(tester), isNull, reason: 'debería poder guardarse');
              await tester.tap(
                find.widgetWithText(ElevatedButton, 'Guardar producto'),
              );
              await tester.pump();

              final producto = capturarProductoCreado(provider);
              expect(producto.modoVenta, ModoVenta.medida);
              expect(producto.modelos, hasLength(1));
              expect(producto.precioCentavos, 1200);
              expect(producto.stockBase, 2 * medida.unidadVisual!.factorBase);
            },
          );
        }
      }
    });
  }
}
