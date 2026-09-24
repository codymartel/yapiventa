import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

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

  static CatalogoVentaPersistido? desdeMapa(Object? valor) {
    if (valor is! Map) return null;
    final datos = Map<String, dynamic>.from(valor);

    final version = datos['versionEsquema'];
    final versionEfectivo =
        version is int && version > 0 ? version : versionEsquema;

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
  final FamiliaUnidad familia;
  final UnidadRegistrada unidadBase;
  final UnidadRegistrada unidadVisual;
  final int minimoBase;
  final int incrementoBase;
  final List<int> cantidadesRapidasBase;
  final bool permiteCantidad;
  final bool permiteMonto;
  final bool activa;
  final bool obligatoria;

  MedidaVentaPersistida({
    required this.id,
    required this.nombre,
    required this.familia,
    required this.unidadBase,
    required this.unidadVisual,
    required this.minimoBase,
    required this.incrementoBase,
    required List<int> cantidadesRapidasBase,
    required this.permiteCantidad,
    required this.permiteMonto,
    required this.activa,
    required this.obligatoria,
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
    final familia = _familiaDesdeTexto(datos['familia']);
    if (id.isEmpty || nombre.isEmpty || familia == null) {
      return null;
    }
    if (familia == FamiliaUnidad.conteo) return null;

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

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'familia': familia.name,
        'unidadBase': unidadBase.nombre,
        'unidadVisual': unidadVisual.nombre,
        'minimoBase': minimoBase,
        'incrementoBase': incrementoBase,
        'cantidadesRapidasBase': cantidadesRapidasBase,
        'permiteCantidad': permiteCantidad,
        'permiteMonto': permiteMonto,
        'activa': activa,
        'obligatoria': obligatoria,
      };

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