import 'package:mobile/domain/models/tipo_unidad.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

import 'catalogo_venta_global.dart';
import 'configuracion_medida.dart';
import 'formato_presentacion.dart';
import 'opcion_presentacion.dart';
import 'preset_venta_rubro.dart';
import 'unidad_registrada.dart';

class CatalogoVentaPersistido {
  static const int versionEsquema = 1;

  final int version;
  final List<OpcionPresentacion> presentaciones;
  final List<MedidaVentaPersistida> medidas;

  CatalogoVentaPersistido({
    this.version = versionEsquema,
    required List<OpcionPresentacion> presentaciones,
    required List<MedidaVentaPersistida> medidas,
  }) : presentaciones = List.unmodifiable(presentaciones),
       medidas = List.unmodifiable(medidas);

  factory CatalogoVentaPersistido.desdePreset(PresetVentaRubro preset) {
    return CatalogoVentaPersistido(
      presentaciones: preset.presentaciones,
      medidas: preset.medidas
          .map(MedidaVentaPersistida.desdeConfiguracion)
          .toList(),
    );
  }

  /// Adapta las [UnidadInfo] legacy de un negocio a este catálogo en memoria.
  ///
  /// Solo se traduce lo que el registro cerrado de unidades permite traducir
  /// de forma segura (peso, volumen, longitud, área y el conteo "unidad" como
  /// presentación). Lo demás nunca se inventa: llega como
  /// [MedidaVentaPersistida.requiereRevision] con familia y unidades nulas.
  /// Devuelve null únicamente cuando no hay nada que adaptar.
  static CatalogoVentaPersistido? desdeUnidadesLegacy(
    Iterable<UnidadInfo> unidades,
  ) {
    final lista = unidades.toList();
    if (lista.isEmpty) return null;

    final medidas = <MedidaVentaPersistida>[];
    final presentaciones = <OpcionPresentacion>[];

    for (final unidad in lista) {
      final nombre = unidad.nombre.trim();
      if (nombre.isEmpty) continue;

      final mapeo = _unidadLegacyARegistro(nombre);
      if (mapeo == null) {
        medidas.add(_medidaRequiereRevision(unidad));
        continue;
      }

      final familia = mapeo.familia;
      if (familia == FamiliaUnidad.conteo) {
        final existe = presentaciones.any(
          (presentacion) => presentacion.id == 'unidad',
        );
        if (!existe) {
          presentaciones.add(
            OpcionPresentacion(
              id: 'unidad',
              nombre: 'Unidad',
              formatos: [
                FormatoPresentacion(
                  valorBase: 1,
                  familia: FamiliaUnidad.conteo,
                  unidadVisible: RegistroUnidades.unidad,
                ),
              ],
              activa: !unidad.esOpcional,
              obligatoria: false,
            ),
          );
        }
        continue;
      }

      medidas.add(_medidaSegura(unidad, mapeo));
    }

    return CatalogoVentaPersistido(
      presentaciones: presentaciones,
      medidas: medidas,
    );
  }

  static MedidaVentaPersistida _medidaSegura(
    UnidadInfo unidad,
    ({FamiliaUnidad familia, UnidadRegistrada unidad}) mapeo,
  ) {
    final porDefecto = CatalogoVentaGlobal.medidaPorDefecto(mapeo.familia);
    return MedidaVentaPersistida(
      id: mapeo.unidad.nombre,
      nombre: unidad.nombre.trim(),
      familia: mapeo.familia,
      unidadBase: RegistroUnidades.baseDe(mapeo.familia),
      unidadVisual: mapeo.unidad,
      minimoBase: porDefecto.minimoBase,
      incrementoBase: porDefecto.incrementoBase,
      cantidadesRapidasBase: porDefecto.cantidadesRapidasBase,
      permiteCantidad: porDefecto.permiteCantidad,
      permiteMonto: porDefecto.permiteMonto,
      activa: !unidad.esOpcional,
      obligatoria: false,
    );
  }

  static MedidaVentaPersistida _medidaRequiereRevision(UnidadInfo unidad) {
    final nombre = unidad.nombre.trim();
    return MedidaVentaPersistida(
      id: nombre,
      nombre: nombre,
      familia: null,
      unidadBase: null,
      unidadVisual: null,
      minimoBase: 0,
      incrementoBase: 0,
      cantidadesRapidasBase: const [],
      permiteCantidad: true,
      permiteMonto: false,
      activa: false,
      obligatoria: false,
      requiereRevision: true,
    );
  }

  /// Busca el nombre legacy en el registro cerrado de unidades comparando sin
  /// distinguir mayúsculas ("Unidad" == "unidad", "L" == "l").
  static ({FamiliaUnidad familia, UnidadRegistrada unidad})?
  _unidadLegacyARegistro(String nombre) {
    final normalizado = nombre.toLowerCase();
    for (final familia in FamiliaUnidad.values) {
      for (final unidad in RegistroUnidades.unidadesDe(familia)) {
        if (unidad.nombre.toLowerCase() == normalizado) {
          return (familia: familia, unidad: unidad);
        }
      }
    }
    return null;
  }

  static CatalogoVentaPersistido? desdeMapa(Object? valor) {
    if (valor is! Map) return null;
    final datos = Map<String, dynamic>.from(valor);

    final version = datos['versionEsquema'];
    final versionEfectivo = version is int && version > 0
        ? version
        : versionEsquema;

    final presentaciones = <OpcionPresentacion>[];
    final presentacionesGuardadas = datos['presentaciones'];
    if (presentacionesGuardadas is List) {
      for (final elemento in presentacionesGuardadas) {
        final presentacion = _presentacionDesdeMapa(elemento);
        if (presentacion != null) presentaciones.add(presentacion);
      }
    }

    final medidas = <MedidaVentaPersistida>[];
    final medidasGuardadas = datos['medidas'];
    if (medidasGuardadas is List) {
      for (final elemento in medidasGuardadas) {
        final medida = MedidaVentaPersistida.desdeMapa(elemento);
        if (medida != null) medidas.add(medida);
      }
    }

    return CatalogoVentaPersistido(
      version: versionEfectivo,
      presentaciones: presentaciones,
      medidas: medidas,
    );
  }

  Map<String, dynamic> toMap() => {
    'versionEsquema': version,
    'presentaciones': presentaciones.map(_presentacionAMapa).toList(),
    'medidas': medidas.map((medida) => medida.toMap()).toList(),
  };

  static Map<String, dynamic> _presentacionAMapa(
    OpcionPresentacion presentacion,
  ) => {
    'id': presentacion.id,
    'nombre': presentacion.nombre,
    'formatos': presentacion.formatos.map(_formatoAMapa).toList(),
    'activa': presentacion.activa,
    'obligatoria': presentacion.obligatoria,
    'personalizada': presentacion.personalizada,
  };

  static Map<String, dynamic> _formatoAMapa(FormatoPresentacion formato) => {
    'valorBase': formato.valorBase,
    'familia': formato.familia.name,
    'unidadVisible': formato.unidadVisible.nombre,
  };

  static OpcionPresentacion? _presentacionDesdeMapa(Object? valor) {
    if (valor is! Map) return null;
    final datos = Map<String, dynamic>.from(valor);
    final id = _texto(datos['id']);
    final nombre = _texto(datos['nombre']);
    if (id.isEmpty || nombre.isEmpty) return null;

    final formatos = <FormatoPresentacion>[];
    final formatosGuardados = datos['formatos'];
    if (formatosGuardados is List) {
      for (final elemento in formatosGuardados) {
        final formato = _formatoDesdeMapa(elemento);
        if (formato != null) formatos.add(formato);
      }
    }
    if (formatos.isEmpty) return null;

    return OpcionPresentacion(
      id: id,
      nombre: nombre,
      formatos: formatos,
      activa: datos['activa'] is bool ? datos['activa'] as bool : true,
      obligatoria: datos['obligatoria'] is bool
          ? datos['obligatoria'] as bool
          : false,
      personalizada: datos['personalizada'] is bool
          ? datos['personalizada'] as bool
          : false,
    );
  }

  static FormatoPresentacion? _formatoDesdeMapa(Object? valor) {
    if (valor is! Map) return null;
    final datos = Map<String, dynamic>.from(valor);
    final valorBase = _enteroPositivo(datos['valorBase']);
    final familia = _familiaDesdeTexto(datos['familia']);
    if (valorBase == null || familia == null) return null;
    final unidadVisible = _unidadDe(familia, _texto(datos['unidadVisible']));
    if (unidadVisible == null) return null;
    return FormatoPresentacion(
      valorBase: valorBase,
      familia: familia,
      unidadVisible: unidadVisible,
    );
  }

  static int? _enteroPositivo(Object? valor) {
    if (valor is! int || valor <= 0) return null;
    return valor;
  }

  static String _texto(Object? valor) {
    final texto = valor;
    return texto is String ? texto.trim() : '';
  }

  static FamiliaUnidad? _familiaDesdeTexto(Object? valor) {
    if (valor is! String) return null;
    for (final familia in FamiliaUnidad.values) {
      if (familia.name == valor) return familia;
    }
    return null;
  }

  static UnidadRegistrada? _unidadDe(FamiliaUnidad familia, String nombre) {
    for (final unidad in RegistroUnidades.unidadesDe(familia)) {
      if (unidad.nombre == nombre) return unidad;
    }
    return null;
  }
}

class MedidaVentaPersistida {
  final String id;
  final String nombre;

  /// null cuando la unidad legacy no tuvo mapeo seguro (requiere revisión).
  final FamiliaUnidad? familia;
  final UnidadRegistrada? unidadBase;
  final UnidadRegistrada? unidadVisual;
  final int minimoBase;
  final int incrementoBase;
  final List<int> cantidadesRapidasBase;
  final bool permiteCantidad;
  final bool permiteMonto;
  final bool activa;
  final bool obligatoria;

  /// true para unidades legacy sin mapeo seguro: no se inventó conversión.
  final bool requiereRevision;

  MedidaVentaPersistida({
    required this.id,
    required this.nombre,
    this.familia,
    this.unidadBase,
    this.unidadVisual,
    this.minimoBase = 0,
    this.incrementoBase = 0,
    List<int> cantidadesRapidasBase = const [],
    this.permiteCantidad = true,
    this.permiteMonto = false,
    this.activa = false,
    this.obligatoria = false,
    this.requiereRevision = false,
  }) : cantidadesRapidasBase = List.unmodifiable(cantidadesRapidasBase);

  factory MedidaVentaPersistida.desdeConfiguracion(
    ConfiguracionMedida configuracion,
  ) {
    return MedidaVentaPersistida(
      id: _idDeFamilia(configuracion.familia),
      nombre: _nombreDeFamilia(configuracion.familia),
      familia: configuracion.familia,
      unidadBase: configuracion.unidadBase,
      unidadVisual: configuracion.unidadVisual,
      minimoBase: configuracion.minimoBase,
      incrementoBase: configuracion.incrementoBase,
      cantidadesRapidasBase: configuracion.cantidadesRapidasBase,
      permiteCantidad: configuracion.permiteCantidad,
      permiteMonto: configuracion.permiteMonto,
      activa: configuracion.activa,
      obligatoria: false,
    );
  }

  static MedidaVentaPersistida? desdeMapa(Object? valor) {
    if (valor is! Map) return null;
    final datos = Map<String, dynamic>.from(valor);
    final id = _texto(datos['id']);
    final nombre = _texto(datos['nombre']);
    if (id.isEmpty || nombre.isEmpty) return null;

    final requiereRevision = datos['requiereRevision'] is bool
        ? datos['requiereRevision'] as bool
        : false;
    final familia = _familiaDesdeTexto(datos['familia']);

    if (requiereRevision) {
      return MedidaVentaPersistida(
        id: id,
        nombre: nombre,
        familia: familia,
        unidadBase: null,
        unidadVisual: null,
        minimoBase: _enteroNoNegativo(datos['minimoBase']),
        incrementoBase: _enteroNoNegativo(datos['incrementoBase']),
        cantidadesRapidasBase: const [],
        permiteCantidad: datos['permiteCantidad'] is bool
            ? datos['permiteCantidad'] as bool
            : true,
        permiteMonto: datos['permiteMonto'] is bool
            ? datos['permiteMonto'] as bool
            : false,
        activa: datos['activa'] is bool ? datos['activa'] as bool : false,
        obligatoria: datos['obligatoria'] is bool
            ? datos['obligatoria'] as bool
            : false,
        requiereRevision: true,
      );
    }

    if (familia == null || familia == FamiliaUnidad.conteo) return null;

    final unidadBase = RegistroUnidades.baseDe(familia);
    final unidadVisual = _unidadDe(familia, _texto(datos['unidadVisual']));
    if (unidadVisual == null) return null;

    final minimoBase = _enteroPositivo(datos['minimoBase']);
    final incrementoBase = _enteroPositivo(datos['incrementoBase']);
    if (minimoBase == null || incrementoBase == null) return null;

    final rapidas = <int>[];
    final rapidasGuardadas = datos['cantidadesRapidasBase'];
    if (rapidasGuardadas is List) {
      for (final elemento in rapidasGuardadas) {
        final cantidad = _enteroPositivo(elemento);
        if (cantidad != null && !rapidas.contains(cantidad)) {
          rapidas.add(cantidad);
        }
      }
    }

    return MedidaVentaPersistida(
      id: id,
      nombre: nombre,
      familia: familia,
      unidadBase: unidadBase,
      unidadVisual: unidadVisual,
      minimoBase: minimoBase,
      incrementoBase: incrementoBase,
      cantidadesRapidasBase: rapidas,
      permiteCantidad: datos['permiteCantidad'] is bool
          ? datos['permiteCantidad'] as bool
          : true,
      permiteMonto: datos['permiteMonto'] is bool
          ? datos['permiteMonto'] as bool
          : false,
      activa: datos['activa'] is bool ? datos['activa'] as bool : false,
      obligatoria: datos['obligatoria'] is bool
          ? datos['obligatoria'] as bool
          : false,
    );
  }

  Map<String, dynamic> toMap() {
    final mapa = <String, dynamic>{
      'id': id,
      'nombre': nombre,
      'minimoBase': minimoBase,
      'incrementoBase': incrementoBase,
      'cantidadesRapidasBase': cantidadesRapidasBase,
      'permiteCantidad': permiteCantidad,
      'permiteMonto': permiteMonto,
      'activa': activa,
      'obligatoria': obligatoria,
      'requiereRevision': requiereRevision,
    };
    if (familia != null) {
      mapa['familia'] = familia!.name;
      mapa['unidadBase'] = unidadBase!.nombre;
      mapa['unidadVisual'] = unidadVisual!.nombre;
    }
    return mapa;
  }

  static String _idDeFamilia(FamiliaUnidad familia) {
    switch (familia) {
      case FamiliaUnidad.peso:
        return 'peso';
      case FamiliaUnidad.volumen:
        return 'volumen';
      case FamiliaUnidad.longitud:
        return 'longitud';
      case FamiliaUnidad.area:
        return 'area';
      case FamiliaUnidad.conteo:
        throw ArgumentError.value(
          familia,
          'familia',
          'El conteo no se vende por medida.',
        );
    }
  }

  static String _nombreDeFamilia(FamiliaUnidad familia) {
    switch (familia) {
      case FamiliaUnidad.peso:
        return 'Peso';
      case FamiliaUnidad.volumen:
        return 'Volumen';
      case FamiliaUnidad.longitud:
        return 'Longitud';
      case FamiliaUnidad.area:
        return 'Área';
      case FamiliaUnidad.conteo:
        throw ArgumentError.value(
          familia,
          'familia',
          'El conteo no se vende por medida.',
        );
    }
  }

  static int? _enteroPositivo(Object? valor) {
    if (valor is! int || valor <= 0) return null;
    return valor;
  }

  static int _enteroNoNegativo(Object? valor) {
    if (valor is! int || valor < 0) return 0;
    return valor;
  }

  static String _texto(Object? valor) {
    final texto = valor;
    return texto is String ? texto.trim() : '';
  }

  static FamiliaUnidad? _familiaDesdeTexto(Object? valor) {
    if (valor is! String) return null;
    for (final familia in FamiliaUnidad.values) {
      if (familia.name == valor) return familia;
    }
    return null;
  }

  static UnidadRegistrada? _unidadDe(FamiliaUnidad familia, String nombre) {
    for (final unidad in RegistroUnidades.unidadesDe(familia)) {
      if (unidad.nombre == nombre) return unidad;
    }
    return null;
  }
}
