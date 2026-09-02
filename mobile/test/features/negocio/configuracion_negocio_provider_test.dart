import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/config_pago_metodo.dart';
import 'package:mobile/features/negocio/domain/models/horario_dia.dart';
import 'package:mobile/features/negocio/domain/models/metodo_pago_tipo.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';
import 'package:mobile/features/negocio/domain/models/zona_delivery.dart';
import 'package:mobile/features/negocio/presentation/providers/configuracion_negocio_provider.dart';

/// Repositorio falso: captura lo que el provider intenta guardar en vez
/// de escribir en Firestore.
class _NegocioRepositoryFake implements NegocioRepository {
  Map<String, dynamic>? guardado;
  bool lanzarError = false;

  @override
  Future<void> guardarConfiguracionNegocio({
    required String uid,
    required String nombreNegocio,
    required String slug,
    required String telefonoCompleto,
    required String direccionCompleta,
    required String ruc,
    required String facebook,
    required String tiktok,
    required String instagram,
    required String youtube,
    required List<String> categorias,
    required List<UnidadInfoResumen> unidadesMedida,
    required bool tieneDelivery,
    required List<ZonaDelivery> zonasDelivery,
    required List<HorarioDia> horarios,
    required List<ConfigPagoMetodo> metodosPagoConfig,
  }) async {
    if (lanzarError) throw Exception('firestore caído');
    guardado = {
      'uid': uid,
      'slug': slug,
      'telefonoCompleto': telefonoCompleto,
      'direccionCompleta': direccionCompleta,
      'categorias': categorias,
    };
  }
}

ConfiguracionNegocioProvider _provider(_NegocioRepositoryFake repo) =>
    ConfiguracionNegocioProvider(rubro: 'Bodega', repository: repo);

/// Deja el paso 1 (datos del negocio) completo y válido.
void _completarPasoNegocio(ConfiguracionNegocioProvider p) {
  p.nombreNegocio = 'Bodega Doña Rosa';
  p.telefono = '987654321';
  p.direccion = 'Av. Los Álamos 123';
  p.referencia = 'Frente al parque';
}

void main() {
  late _NegocioRepositoryFake repo;

  setUp(() => repo = _NegocioRepositoryFake());

  group('Paso 1 — datos del negocio', () {
    test('no deja avanzar con los campos vacíos', () {
      final p = _provider(repo);
      expect(p.puedeAvanzarPaso0, isFalse);
      expect(p.faltaNombre, isTrue);
      expect(p.faltaTelefono, isTrue);
    });

    test('deja avanzar cuando nombre, teléfono, dirección y referencia son válidos', () {
      final p = _provider(repo);
      _completarPasoNegocio(p);
      expect(p.puedeAvanzarPaso0, isTrue);
    });

    test('el teléfono se recorta a los dígitos del país elegido', () {
      final p = _provider(repo);
      p.telefono = '(987) 654-321';
      expect(p.telefono, '987654321'); // Perú, 9 dígitos

      p.paisTelefono = paisesLatam.firstWhere((x) => x.nombre == 'Bolivia');
      p.telefono = '123456789012';
      expect(p.telefono, '12345678'); // Bolivia, 8 dígitos
    });

    test('cambiar de país invalida un teléfono con la longitud de otro país', () {
      final p = _provider(repo);
      _completarPasoNegocio(p); // 9 dígitos, válido en Perú
      p.paisTelefono = paisesLatam.firstWhere((x) => x.nombre == 'Colombia');
      expect(p.faltaTelefono, isTrue); // Colombia espera 10
    });

    test('los links de redes deben empezar con https y no ser sitios prohibidos', () {
      final p = _provider(repo);
      expect(p.linksMalos, isFalse); // vacíos son válidos

      p.linkFacebook = 'facebook.com/mi-bodega';
      expect(p.linksMalos, isTrue);

      p.linkFacebook = 'https://facebook.com/mi-bodega';
      expect(p.linksMalos, isFalse);

      p.linkTiktok = 'https://onlyfans.com/algo';
      expect(p.linksMalos, isTrue);
    });
  });

  group('Pasos 2 y 3 — catálogo y logística', () {
    test('el catálogo arranca con las categorías del rubro', () {
      final p = _provider(repo);
      expect(p.categorias, contains('Abarrotes'));
      expect(p.puedeAvanzarPaso1, isTrue);
    });

    test('sin categorías no se puede avanzar', () {
      final p = _provider(repo);
      while (p.categorias.isNotEmpty) {
        p.eliminarCategoria(0);
      }
      expect(p.puedeAvanzarPaso1, isFalse);
    });

    test('con delivery activo hace falta al menos una zona', () {
      final p = _provider(repo);
      p.tieneDelivery = true;
      expect(p.puedeAvanzarPaso2, isFalse);

      p.agregarZona(const ZonaDelivery(zona: 'Centro', costo: '5'));
      expect(p.puedeAvanzarPaso2, isTrue);
    });
  });

  group('guardar()', () {
    test('arma el slug con el nombre normalizado y los últimos 4 dígitos', () async {
      final p = _provider(repo);
      _completarPasoNegocio(p);

      expect(await p.guardar('uid-1'), isTrue);
      expect(repo.guardado!['slug'], 'bodega-dona-rosa-4321');
      expect(repo.guardado!['telefonoCompleto'], '+51987654321');
      expect(repo.guardado!['direccionCompleta'],
          'Av. Los Álamos 123 (Ref: Frente al parque)');
    });

    test('valida el número de pago contra los dígitos del país, no contra 9 fijos',
        () async {
      final p = _provider(repo);
      _completarPasoNegocio(p);
      p.paisTelefono = paisesLatam.firstWhere((x) => x.nombre == 'Colombia');
      p.telefono = '3001234567'; // 10 dígitos

      final indiceYape = MetodoPagoTipo.todos
          .indexWhere((t) => t.id == MetodoPagoTipo.yape.id);
      p.actualizarMetodoPago(
        indiceYape,
        (c) => c.copyWith(activo: true, numeroPago: '3001234567'),
      );

      expect(await p.guardar('uid-1'), isTrue);
      expect(p.errorValidacion, isNull);
    });

    test('rechaza un número de pago con la cantidad de dígitos equivocada', () async {
      final p = _provider(repo);
      _completarPasoNegocio(p);

      final indiceYape = MetodoPagoTipo.todos
          .indexWhere((t) => t.id == MetodoPagoTipo.yape.id);
      p.actualizarMetodoPago(
        indiceYape,
        (c) => c.copyWith(activo: true, numeroPago: '12345'),
      );

      expect(await p.guardar('uid-1'), isFalse);
      expect(p.errorValidacion, contains('9 dígitos'));
      expect(repo.guardado, isNull);
    });

    test('rechaza un descuento porcentual fuera de rango', () async {
      final p = _provider(repo);
      _completarPasoNegocio(p);

      final indiceYape = MetodoPagoTipo.todos
          .indexWhere((t) => t.id == MetodoPagoTipo.yape.id);
      p.actualizarMetodoPago(
        indiceYape,
        (c) => c.copyWith(
          activo: true,
          numeroPago: '987654321',
          descuentoActivo: true,
          tipoDescuento: TipoDescuento.porcentaje,
          valorDescuento: '150',
        ),
      );

      expect(await p.guardar('uid-1'), isFalse);
      expect(p.errorValidacion, contains('0% y 100%'));
    });

    test('no guarda si hay delivery activo sin zonas', () async {
      final p = _provider(repo);
      _completarPasoNegocio(p);
      p.tieneDelivery = true;

      expect(await p.guardar('uid-1'), isFalse);
      expect(p.errorValidacion, contains('zona de delivery'));
      expect(repo.guardado, isNull);
    });

    test('un fallo del repositorio deja el provider fuera del estado "guardando"',
        () async {
      final p = _provider(repo);
      _completarPasoNegocio(p);
      repo.lanzarError = true;

      expect(await p.guardar('uid-1'), isFalse);
      expect(p.guardando, isFalse);
      expect(p.errorValidacion, isNotNull);
    });
  });
}
