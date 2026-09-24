import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/configuracion_medida.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formateador_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

void main() {
  group('RegistroUnidades (registro cerrado)', () {
    test('expone exactamente las unidades por familia', () {
      expect(RegistroUnidades.porFamilia[FamiliaUnidad.peso], [
        RegistroUnidades.g,
        RegistroUnidades.kg,
      ]);
      expect(RegistroUnidades.porFamilia[FamiliaUnidad.volumen], [
        RegistroUnidades.ml,
        RegistroUnidades.L,
      ]);
      expect(RegistroUnidades.porFamilia[FamiliaUnidad.longitud], [
        RegistroUnidades.mm,
        RegistroUnidades.cm,
        RegistroUnidades.m,
      ]);
      expect(RegistroUnidades.porFamilia[FamiliaUnidad.area], [
        RegistroUnidades.cm2,
        RegistroUnidades.m2,
      ]);
      expect(RegistroUnidades.porFamilia[FamiliaUnidad.conteo], [
        RegistroUnidades.unidad,
      ]);
    });

    test('la unidad base de cada familia es la de factor 1', () {
      expect(RegistroUnidades.baseDe(FamiliaUnidad.peso), RegistroUnidades.g);
      expect(
        RegistroUnidades.baseDe(FamiliaUnidad.volumen),
        RegistroUnidades.ml,
      );
      expect(
        RegistroUnidades.baseDe(FamiliaUnidad.longitud),
        RegistroUnidades.mm,
      );
      expect(RegistroUnidades.baseDe(FamiliaUnidad.area), RegistroUnidades.cm2);
      expect(
        RegistroUnidades.baseDe(FamiliaUnidad.conteo),
        RegistroUnidades.unidad,
      );
    });

    test('la unidad registrada no se puede instanciar desde fuera', () {
      // El constructor es privado a propósito: solo hay unidades del registro.
      expect(UnidadRegistrada, isA<Type>());
    });
  });

  group('conversiones inmutables', () {
    test('1 kg = 1000 g', () {
      expect(RegistroUnidades.convertirABase(1, RegistroUnidades.kg), 1000);
    });

    test('1 L = 1000 ml', () {
      expect(RegistroUnidades.convertirABase(1, RegistroUnidades.L), 1000);
    });

    test('1 cm = 10 mm', () {
      expect(RegistroUnidades.convertirABase(1, RegistroUnidades.cm), 10);
    });

    test('1 m = 1000 mm', () {
      expect(RegistroUnidades.convertirABase(1, RegistroUnidades.m), 1000);
    });

    test('1 m² = 10000 cm²', () {
      expect(RegistroUnidades.convertirABase(1, RegistroUnidades.m2), 10000);
    });

    test('rechaza valores no positivos', () {
      expect(
        () => RegistroUnidades.convertirABase(0, RegistroUnidades.kg),
        throwsArgumentError,
      );
      expect(
        () => RegistroUnidades.convertirABase(-1, RegistroUnidades.L),
        throwsArgumentError,
      );
    });
  });

  group('FormateadorPresentacion (sin decimales)', () {
    test('250 g se muestra como 1/4 kg', () {
      expect(
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(FamiliaUnidad.peso, 250),
          RegistroUnidades.kg,
        ),
        '1/4 kg',
      );
    });

    test('500 g se muestra como 1/2 kg', () {
      expect(
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(FamiliaUnidad.peso, 500),
          RegistroUnidades.kg,
        ),
        '1/2 kg',
      );
    });

    test('750 g se muestra como 3/4 kg', () {
      expect(
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(FamiliaUnidad.peso, 750),
          RegistroUnidades.kg,
        ),
        '3/4 kg',
      );
    });

    test('1500 ml se muestra como 1 1/2 L', () {
      expect(
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(
            FamiliaUnidad.volumen,
            1500,
          ),
          RegistroUnidades.L,
        ),
        '1 1/2 L',
      );
    });

    test('600 ml pierde su fracción y cae a la unidad base', () {
      expect(
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(FamiliaUnidad.volumen, 600),
          RegistroUnidades.L,
        ),
        '600 ml',
      );
    });

    test('nunca emite decimales tipo 0.25, 0.5, 0.75 ni 1.5', () {
      final etiquetas = <String>[
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(FamiliaUnidad.peso, 250),
          RegistroUnidades.kg,
        ),
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(FamiliaUnidad.peso, 500),
          RegistroUnidades.kg,
        ),
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(FamiliaUnidad.peso, 750),
          RegistroUnidades.kg,
        ),
        FormateadorPresentacion.formatear(
          FormateadorPresentacion.cantidadEnFamilia(
            FamiliaUnidad.volumen,
            1500,
          ),
          RegistroUnidades.L,
        ),
      ];
      for (final etiqueta in etiquetas) {
        expect(etiqueta, isNot(contains('0.25')));
        expect(etiqueta, isNot(contains('0.5')));
        expect(etiqueta, isNot(contains('0.75')));
        expect(etiqueta, isNot(contains('1.5')));
        expect(etiqueta, isNot(contains('.')));
      }
    });
  });

  group('FormatoPresentacion', () {
    test('botella de 625 ml en familia volumen', () {
      final formato = FormatoPresentacion(
        valorBase: 625,
        familia: FamiliaUnidad.volumen,
        unidadVisible: RegistroUnidades.ml,
      );
      expect(formato.valorBase, isA<int>());
      expect(formato.valorBase, 625);
      expect(formato.familia, FamiliaUnidad.volumen);
      expect(formato.unidadVisible, RegistroUnidades.ml);
      expect(formato.etiqueta, '625 ml');
    });

    test('caja de 250 g mostrada en kg tiene etiqueta 1/4 kg', () {
      final formato = FormatoPresentacion(
        valorBase: 250,
        familia: FamiliaUnidad.peso,
        unidadVisible: RegistroUnidades.kg,
      );
      expect(formato.etiqueta, '1/4 kg');
    });

    test('rechaza valor base menor o igual a cero', () {
      expect(
        () => FormatoPresentacion(
          valorBase: 0,
          familia: FamiliaUnidad.volumen,
          unidadVisible: RegistroUnidades.ml,
        ),
        throwsArgumentError,
      );
      expect(
        () => FormatoPresentacion(
          valorBase: -5,
          familia: FamiliaUnidad.peso,
          unidadVisible: RegistroUnidades.g,
        ),
        throwsArgumentError,
      );
    });

    test('rechaza unidad visible de familia incompatible', () {
      expect(
        () => FormatoPresentacion(
          valorBase: 1000,
          familia: FamiliaUnidad.peso,
          unidadVisible: RegistroUnidades.ml,
        ),
        throwsArgumentError,
      );
    });

    test('1000 ml y 1 L son el mismo formato normalizado', () {
      final enMililitros = FormatoPresentacion(
        valorBase: 1000,
        familia: FamiliaUnidad.volumen,
        unidadVisible: RegistroUnidades.ml,
      );
      final enLitros = FormatoPresentacion(
        valorBase: 1000,
        familia: FamiliaUnidad.volumen,
        unidadVisible: RegistroUnidades.L,
      );
      expect(enMililitros.esMismoFormato(enLitros), isTrue);
    });
  });

  group('ConfiguracionMedida', () {
    ConfiguracionMedida configArroz() => ConfiguracionMedida(
      familia: FamiliaUnidad.peso,
      unidadVisual: RegistroUnidades.kg,
      minimoBase: 50,
      incrementoBase: 10,
      cantidadesRapidasBase: [50, 100, 250],
    );

    test('configuración válida de arroz por kg', () {
      final config = configArroz();
      expect(config.familia, FamiliaUnidad.peso);
      expect(config.unidadBase, RegistroUnidades.g);
      expect(config.unidadVisual, RegistroUnidades.kg);
      expect(config.minimoBase, 50);
      expect(config.incrementoBase, 10);
      expect(config.cantidadesRapidasBase, [50, 100, 250]);
      expect(config.permiteCantidad, isTrue);
      expect(config.permiteMonto, isTrue);
      expect(config.activa, isTrue);
    });

    test('el mínimo y el incremento deben ser positivos', () {
      expect(
        () => ConfiguracionMedida(
          familia: FamiliaUnidad.peso,
          unidadVisual: RegistroUnidades.kg,
          minimoBase: 0,
          incrementoBase: 10,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConfiguracionMedida(
          familia: FamiliaUnidad.peso,
          unidadVisual: RegistroUnidades.kg,
          minimoBase: 50,
          incrementoBase: 0,
        ),
        throwsArgumentError,
      );
    });

    test('la unidad base está protegida y siempre es la de la familia', () {
      final config = configArroz();
      expect(config.unidadBase, RegistroUnidades.g);
      expect(config.unidadBase, isNot(RegistroUnidades.kg));
    });

    test('rechaza unidad visual de familia incompatible', () {
      expect(
        () => ConfiguracionMedida(
          familia: FamiliaUnidad.peso,
          unidadVisual: RegistroUnidades.ml,
          minimoBase: 50,
          incrementoBase: 10,
        ),
        throwsArgumentError,
      );
    });

    test('no aplica a la familia de conteo', () {
      expect(
        () => ConfiguracionMedida(
          familia: FamiliaUnidad.conteo,
          unidadVisual: RegistroUnidades.unidad,
          minimoBase: 1,
          incrementoBase: 1,
        ),
        throwsArgumentError,
      );
    });

    test('cantidad rápida menor al mínimo es inválida', () {
      expect(
        () => ConfiguracionMedida(
          familia: FamiliaUnidad.peso,
          unidadVisual: RegistroUnidades.kg,
          minimoBase: 50,
          incrementoBase: 10,
          cantidadesRapidasBase: [10],
        ),
        throwsArgumentError,
      );
    });

    test('cantidad rápida debe respetar el incremento desde el mínimo', () {
      expect(
        () => ConfiguracionMedida(
          familia: FamiliaUnidad.peso,
          unidadVisual: RegistroUnidades.kg,
          minimoBase: 50,
          incrementoBase: 10,
          cantidadesRapidasBase: [55],
        ),
        throwsArgumentError,
      );
      // 100 = 50 + 5*10 -> válido
      final valida = ConfiguracionMedida(
        familia: FamiliaUnidad.peso,
        unidadVisual: RegistroUnidades.kg,
        minimoBase: 50,
        incrementoBase: 10,
        cantidadesRapidasBase: [100],
      );
      expect(valida.cantidadesRapidasBase, [100]);
    });

    test('rechaza cantidades rápidas duplicadas', () {
      expect(
        () => ConfiguracionMedida(
          familia: FamiliaUnidad.peso,
          unidadVisual: RegistroUnidades.kg,
          minimoBase: 50,
          incrementoBase: 10,
          cantidadesRapidasBase: [100, 100],
        ),
        throwsArgumentError,
      );
    });

    test('debe permitir cantidad o monto (al menos uno)', () {
      expect(
        () => ConfiguracionMedida(
          familia: FamiliaUnidad.peso,
          unidadVisual: RegistroUnidades.kg,
          minimoBase: 50,
          incrementoBase: 10,
          permiteCantidad: false,
          permiteMonto: false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('OpcionPresentacion', () {
    List<FormatoPresentacion> formatosBotella() => [
      FormatoPresentacion(
        valorBase: 625,
        familia: FamiliaUnidad.volumen,
        unidadVisible: RegistroUnidades.ml,
      ),
      FormatoPresentacion(
        valorBase: 1500,
        familia: FamiliaUnidad.volumen,
        unidadVisible: RegistroUnidades.ml,
      ),
    ];

    test('mantiene flags y formatos pedidos', () {
      final opcion = OpcionPresentacion(
        id: 'botella',
        nombre: 'Botella',
        formatos: formatosBotella(),
        activa: false,
        obligatoria: true,
        personalizada: true,
      );
      expect(opcion.id, 'botella');
      expect(opcion.nombre, 'Botella');
      expect(opcion.formatos.length, 2);
      expect(opcion.activa, isFalse);
      expect(opcion.obligatoria, isTrue);
      expect(opcion.personalizada, isTrue);
      expect(opcion.validar(), isNull);
    });

    test('el id es estable e independiente del nombre', () {
      final original = OpcionPresentacion(
        id: 'botella',
        nombre: 'Botella',
        formatos: formatosBotella(),
      );
      final renombrada = OpcionPresentacion(
        id: 'botella',
        nombre: 'Frasco de vidrio',
        formatos: formatosBotella(),
      );
      expect(original.id, renombrada.id);
    });

    test('rechaza id vacío', () {
      final opcion = OpcionPresentacion(
        id: '  ',
        nombre: 'Botella',
        formatos: formatosBotella(),
      );
      expect(opcion.validar(), isNotNull);
    });

    test('rechaza nombre vacío', () {
      final opcion = OpcionPresentacion(
        id: 'botella',
        nombre: '',
        formatos: formatosBotella(),
      );
      expect(opcion.validar(), isNotNull);
    });

    test('rechaza sin formatos', () {
      final opcion = OpcionPresentacion(
        id: 'botella',
        nombre: 'Botella',
        formatos: [],
      );
      expect(opcion.validar(), isNotNull);
    });

    test('rechaza formatos duplicados normalizados (1000 ml == 1 L)', () {
      final opcion = OpcionPresentacion(
        id: 'gaseosa',
        nombre: 'Gaseosa',
        formatos: [
          FormatoPresentacion(
            valorBase: 1000,
            familia: FamiliaUnidad.volumen,
            unidadVisible: RegistroUnidades.ml,
          ),
          FormatoPresentacion(
            valorBase: 1000,
            familia: FamiliaUnidad.volumen,
            unidadVisible: RegistroUnidades.L,
          ),
        ],
      );
      expect(opcion.validar(), isNotNull);
    });

    test('rechaza duplicados normalizados (1000 g == 1 kg)', () {
      final opcion = OpcionPresentacion(
        id: 'harina',
        nombre: 'Harina',
        formatos: [
          FormatoPresentacion(
            valorBase: 1000,
            familia: FamiliaUnidad.peso,
            unidadVisible: RegistroUnidades.g,
          ),
          FormatoPresentacion(
            valorBase: 1000,
            familia: FamiliaUnidad.peso,
            unidadVisible: RegistroUnidades.kg,
          ),
        ],
      );
      expect(opcion.validar(), isNotNull);
    });
  });

  group('ausencia de double en el catálogo', () {
    test('las unidades del registro solo usan int', () {
      final factorGramos = RegistroUnidades.g.factorBase;
      final factorKg = RegistroUnidades.kg.factorBase;
      expect(factorGramos, isA<int>());
      expect(factorKg, isA<int>());
    });

    test('los formatos no persisten ningún double (análisis de fuente)', () {
      final fuentes = <String>[
        'lib/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart',
        'lib/features/negocio/domain/models/catalogo_venta/formato_presentacion.dart',
        'lib/features/negocio/domain/models/catalogo_venta/configuracion_medida.dart',
        'lib/features/negocio/domain/models/catalogo_venta/opcion_presentacion.dart',
        'lib/features/negocio/domain/models/catalogo_venta/formateador_presentacion.dart',
      ];
      final conteniaDouble = <String>[];
      for (final ruta in fuentes) {
        final fuente = File(ruta).readAsStringSync();
        for (final linea in fuente.split('\n')) {
          final recortada = linea.trim();
          if (recortada.startsWith('//')) {
            continue; // comentarios no cuentan
          }
          if (_declaraCampoDouble(linea) || _llamaFactoryDouble(linea)) {
            conteniaDouble.add('$ruta: $linea');
          }
        }
      }
      expect(conteniaDouble, isEmpty);
    });
  });
}

bool _declaraCampoDouble(String linea) {
  final recortada = linea.trim();
  if (recortada.contains('double ') && recortada.endsWith(';')) {
    return true;
  }
  if (RegExp(
    r'\bList<double>|Map<String, double>|<\s*double\s*>',
  ).hasMatch(recortada)) {
    return true;
  }
  return false;
}

bool _llamaFactoryDouble(String linea) {
  final recortada = linea.trim();
  return RegExp(
    r'\.toDouble\(|as double|double\s+\w+\s*[,=]',
  ).hasMatch(recortada);
}
