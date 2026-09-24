import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

import 'configuracion_medida.dart';
import 'formato_presentacion.dart';
import 'opcion_presentacion.dart';
import 'unidad_registrada.dart';

// ═════════════════════════════════════════════════════════════════════════
// CatalogoVentaGlobal
// ═════════════════════════════════════════════════════════════════════════
// Catálogo GLOBAL PROTEGIDO de formas de venta. Existe para TODOS los rubros
// y es la única fuente de verdad de lo que se puede configurar:
//
//   - presentaciones: ids estables + sus formatos permitidos. Todo nuevo
//     preset DEBE referenciar estos ids y solo puede usar formatos que ya
//     existen aquí (comparación normalizada por familia + valorBase).
//   - medidas: solo las familias {peso, volumen, longitud, area} con
//     configuraciones por defecto válidas. Conteo NO es una medida.
//
// El rubro NUNCA inventa familias, unidades ni conversiones: esas viven en
// RegistroUnidades / FamiliaUnidad / FormateadorPresentacion (cerradas).
// Este catálogo garantiza que "aparecer obligatorio, activo, opcional o
// inactivo" sea lo ÚNICO que cambia entre rubros.
// ═════════════════════════════════════════════════════════════════════════
enum EstadoVenta { obligatoria, activa, opcional, inactiva }

class CatalogoVentaGlobal {
  CatalogoVentaGlobal._();

  static FormatoPresentacion _volumen(int valor) {
    final unidad = valor >= 1000 ? RegistroUnidades.L : RegistroUnidades.ml;
    return FormatoPresentacion(
      valorBase: valor,
      familia: FamiliaUnidad.volumen,
      unidadVisible: unidad,
    );
  }

  static FormatoPresentacion _peso(int valor) {
    final unidad = valor >= 1000 ? RegistroUnidades.kg : RegistroUnidades.g;
    return FormatoPresentacion(
      valorBase: valor,
      familia: FamiliaUnidad.peso,
      unidadVisible: unidad,
    );
  }

  static FormatoPresentacion _conteo(int valor) => FormatoPresentacion(
        valorBase: valor,
        familia: FamiliaUnidad.conteo,
        unidadVisible: RegistroUnidades.unidad,
      );

  /// Nombres visibles de cada presentación (ids estables).
  static const Map<String, String> nombres = {
    'unidad': 'Unidad',
    'botella': 'Botella',
    'lata': 'Lata',
    'bolsa': 'Bolsa',
    'caja': 'Caja',
    'paquete': 'Paquete',
    'vaso': 'Vaso',
    'jarra': 'Jarra',
    'porcion': 'Porción',
    'plato': 'Plato',
    'combo': 'Combo',
    'par': 'Par',
    'conjunto': 'Conjunto',
    'set': 'Set',
    'juego': 'Juego',
    'frasco': 'Frasco',
    'pote': 'Pote',
    'tubo': 'Tubo',
    'sachet': 'Sachet',
    'spray': 'Spray',
  };

  /// Formatos permitidos por presentación (fuente de verdad).
  static final Map<String, List<FormatoPresentacion>> _formatosPorId = {
    'unidad': [_conteo(1)],
    'botella': [
      _volumen(100),
      _volumen(200),
      _volumen(250),
      _volumen(500),
      _volumen(625),
      _volumen(650),
      _volumen(750),
      _volumen(1000),
      _volumen(1500),
      _volumen(2000),
      _volumen(2500),
      _volumen(3000),
    ],
    'lata': [
      _peso(170),
      _volumen(355),
      _peso(400),
    ],
    'bolsa': [
      _peso(100),
      _peso(250),
      _peso(500),
      _peso(1000),
    ],
    'caja': [_conteo(6), _conteo(12), _conteo(24)],
    'paquete': [_conteo(6), _conteo(12), _conteo(24)],
    'vaso': [_volumen(250), _volumen(350), _volumen(500)],
    'jarra': [_volumen(1000), _volumen(1500), _volumen(2000)],
    'porcion': [_conteo(1)],
    'plato': [_conteo(1)],
    'combo': [_conteo(1)],
    'par': [_conteo(1)],
    'conjunto': [_conteo(1)],
    'set': [_conteo(1)],
    'juego': [_conteo(1)],
    'frasco': [
      _volumen(30),
      _volumen(50),
      _volumen(100),
      _volumen(120),
      _volumen(200),
      _volumen(250),
      _volumen(500),
    ],
    'pote': [_peso(30), _peso(50), _peso(100), _peso(250), _peso(500)],
    'tubo': [_peso(30), _peso(50), _peso(100), _peso(250), _peso(500)],
    'sachet': [_volumen(5), _volumen(10), _volumen(15), _volumen(20)],
    'spray': [_conteo(1)],
  };

  /// Familias que pueden venderse por medida. Conteo se cuenta, no se mide.
  static const List<FamiliaUnidad> familiasMedida = [
    FamiliaUnidad.peso,
    FamiliaUnidad.volumen,
    FamiliaUnidad.longitud,
    FamiliaUnidad.area,
  ];

  static bool esIdValido(String id) => nombres.containsKey(id);

  static String nombreDe(String id) {
    final nombre = nombres[id];
    if (nombre == null) {
      throw ArgumentError.value(id, 'id', 'Presentación desconocida.');
    }
    return nombre;
  }

  /// Todos los formatos permitidos de una presentación (no modificable).
  static List<FormatoPresentacion> formatosDe(String id,
      {List<int>? valoresBase}) {
    final disponibles = _formatosPorId[id];
    if (disponibles == null) {
      throw ArgumentError.value(id, 'id', 'Presentación desconocida.');
    }
    if (valoresBase == null) {
      return List.unmodifiable(disponibles);
    }
    final pedidos = valoresBase.toSet();
    return List.unmodifiable(
      disponibles
          .where((formato) => pedidos.contains(formato.valorBase))
          .toList(),
    );
  }

  /// true si familia + valorBase están permitidos para la presentación.
  static bool esFormatoPermitido(String id, FormatoPresentacion formato) {
    final disponibles = _formatosPorId[id];
    if (disponibles == null) return false;
    return disponibles.any(
      (f) => f.familia == formato.familia && f.valorBase == formato.valorBase,
    );
  }

  static bool esFamiliaDeMedida(FamiliaUnidad familia) =>
      familiasMedida.contains(familia);

  /// Configuración por defecto válida de una familia de medida.
  static ConfiguracionMedida medidaPorDefecto(FamiliaUnidad familia) {
    switch (familia) {
      case FamiliaUnidad.peso:
        return ConfiguracionMedida(
          familia: familia,
          unidadVisual: RegistroUnidades.kg,
          minimoBase: 100,
          incrementoBase: 50,
          cantidadesRapidasBase: const [250, 500, 750, 1000],
          permiteCantidad: true,
          monto: EstadoMonto.inactivo,
          activa: false,
        );
      case FamiliaUnidad.volumen:
        return ConfiguracionMedida(
          familia: familia,
          unidadVisual: RegistroUnidades.L,
          minimoBase: 250,
          incrementoBase: 250,
          cantidadesRapidasBase: const [250, 500, 750, 1000],
          permiteCantidad: true,
          monto: EstadoMonto.inactivo,
          activa: false,
        );
      case FamiliaUnidad.longitud:
        return ConfiguracionMedida(
          familia: familia,
          unidadVisual: RegistroUnidades.m,
          minimoBase: 100,
          incrementoBase: 100,
          cantidadesRapidasBase: const [500, 1000, 1500, 2000],
          permiteCantidad: true,
          monto: EstadoMonto.inactivo,
          activa: false,
        );
      case FamiliaUnidad.area:
        return ConfiguracionMedida(
          familia: familia,
          unidadVisual: RegistroUnidades.m2,
          minimoBase: 100,
          incrementoBase: 100,
          cantidadesRapidasBase: const [100, 200, 300],
          permiteCantidad: true,
          monto: EstadoMonto.inactivo,
          activa: false,
        );
      case FamiliaUnidad.conteo:
        throw ArgumentError.value(
          familia,
          'familia',
          'El conteo no se vende por medida.',
        );
    }
  }

  /// Valida una opción: id conocido, formatos permitidos del id y sin
  /// duplicados normalizados. null si todo es válido.
  static String? validarOpcion(
    String id,
    List<FormatoPresentacion> formatos,
  ) {
    if (!esIdValido(id)) {
      return 'La presentación "$id" no existe en el catálogo global.';
    }
    if (formatos.isEmpty) {
      return 'La presentación debe tener al menos un formato.';
    }
    final vistos = <(FamiliaUnidad, int)>{};
    for (final formato in formatos) {
      if (!esFormatoPermitido(id, formato)) {
        return 'El formato ${formato.valorBase} no está permitido para '
            '"$id".';
      }
      if (!vistos.add((formato.familia, formato.valorBase))) {
        return 'Formato duplicado normalizado para "$id".';
      }
    }
    return null;
  }

  /// Construye una [OpcionPresentacion] del catálogo global con su estado.
  static OpcionPresentacion opcionVenta(String id, EstadoVenta estado,
      {required List<FormatoPresentacion> formatos}) {
    final error = validarOpcion(id, formatos);
    if (error != null) {
      throw ArgumentError(error);
    }
    return OpcionPresentacion(
      id: id,
      nombre: nombreDe(id),
      formatos: formatos,
      activa: estado != EstadoVenta.inactiva && estado != EstadoVenta.opcional,
      obligatoria: estado == EstadoVenta.obligatoria,
    );
  }
}