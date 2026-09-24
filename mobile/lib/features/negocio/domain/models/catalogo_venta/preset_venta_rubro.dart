// ═════════════════════════════════════════════════════════════════════════
// PresetVentaRubro + PresetsVenta
// ═════════════════════════════════════════════════════════════════════════
// Qué vende cada rubro, construido SIEMPRE sobre el CatalogoVentaGlobal.
// El rubro NO inventa presentaciones, formatos, familias ni conversiones:
// solo decide en qué estado aparece cada cosa del catálogo global:
//
//   - obligatoria : se activa y no se puede desactivar.
//   - activa      : se activa por defecto.
//   - opcional    : disponible en el rubro pero sin activar.
//   - inactiva    : no aparece en el rubro (solo resoluble vía estadoDe).
//
// Medidas: solo familias {peso, volumen, longitud, area}; conteo jamás se
// vende por medida. Mínimo, incremento y rápidas van SIEMPRE en unidad base
// y sin double. El monto de cada medida decide si está activo, opcional
// (disponible sin activar) o inactivo. Envase cerrado (botella, lata, plato,
// combo, porción) es presentación y se cuenta; SOLO el granel real se vende
// por medida. Talla y color NO son medidas ni formatos: son atributos ajenos
// a las formas de venta. Solo "Otros" admite presentaciones personalizadas.
// ═════════════════════════════════════════════════════════════════════════
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

import 'catalogo_venta_global.dart';
import 'configuracion_medida.dart';
import 'formato_presentacion.dart';
import 'opcion_presentacion.dart';
import 'unidad_registrada.dart';

/// Estado de una presentación dentro de un preset.
typedef PresentacionACrear = ({
  EstadoVenta estado,
  List<FormatoPresentacion> formatos,
});

class PresetVentaRubro {
  final String rubro;
  final List<String> categorias;
  final List<OpcionPresentacion> presentaciones;
  final List<ConfiguracionMedida> medidas;

  /// Solo "Otros" admite presentaciones personalizadas; el resto no. Nunca
  /// implica familias, unidades ni conversiones nuevas (registro cerrado).
  final bool permitePersonalizadas;

  final Map<String, EstadoVenta> _estadosPorId;

  PresetVentaRubro._({
    required this.rubro,
    required List<String> categorias,
    required List<OpcionPresentacion> presentaciones,
    required List<ConfiguracionMedida> medidas,
    required this.permitePersonalizadas,
    required Map<String, EstadoVenta> estadosPorId,
  }) : categorias = List.unmodifiable(categorias),
       presentaciones = List.unmodifiable(presentaciones),
       medidas = List.unmodifiable(medidas),
       _estadosPorId = Map.unmodifiable(estadosPorId);

  /// Construye y valida el preset contra el [CatalogoVentaGlobal].
  /// Lanza [ArgumentError] si intenta algo fuera del catálogo global.
  factory PresetVentaRubro.modelar({
    required String rubro,
    required List<String> categorias,
    required Map<String, PresentacionACrear> presentaciones,
    required List<ConfiguracionMedida> medidas,
    bool permitePersonalizadas = false,
  }) {
    if (rubro.trim().isEmpty) {
      throw ArgumentError.value(rubro, 'rubro', 'El rubro no puede estar vacío.');
    }
    if (categorias.isEmpty) {
      throw ArgumentError.value(
        rubro,
        'rubro',
        'El preset debe incluir al menos una categoría.',
      );
    }
    if (categorias.any((categoria) => categoria.trim().isEmpty)) {
      throw ArgumentError.value(rubro, 'rubro', 'Las categorías no pueden ser vacías.');
    }
    if (categorias.toSet().length != categorias.length) {
      throw ArgumentError.value(rubro, 'rubro', 'Las categorías no pueden repetirse.');
    }

    final opciones = <OpcionPresentacion>[];
    final estados = <String, EstadoVenta>{};
    final idsVistos = <String>{};
    for (final entrada in presentaciones.entries) {
      final id = entrada.key;
      final aCrear = entrada.value;

      if (aCrear.estado == EstadoVenta.inactiva) {
        throw ArgumentError.value(
          id,
          'presentaciones',
          '[$rubro] La inactiva significa ausencia: no la incluyas.',
        );
      }
      if (!idsVistos.add(id)) {
        throw ArgumentError.value(id, 'presentaciones', 'Presentación duplicada.');
      }

      final error = CatalogoVentaGlobal.validarOpcion(id, aCrear.formatos);
      if (error != null) {
        throw ArgumentError('[$rubro] $error');
      }
      opciones.add(
        CatalogoVentaGlobal.opcionVenta(id, aCrear.estado, formatos: aCrear.formatos),
      );
      estados[id] = aCrear.estado;
    }

    final familiasVistas = <FamiliaUnidad>{};
    for (final configuracion in medidas) {
      if (!CatalogoVentaGlobal.esFamiliaDeMedida(configuracion.familia)) {
        throw ArgumentError.value(
          configuracion.familia,
          'medidas',
          '[$rubro] El conteo no se vende por medida.',
        );
      }
      if (!familiasVistas.add(configuracion.familia)) {
        throw ArgumentError.value(
          configuracion.familia,
          'medidas',
          '[$rubro] Medida de familia duplicada.',
        );
      }
    }

    return PresetVentaRubro._(
      rubro: rubro,
      categorias: categorias,
      presentaciones: opciones,
      medidas: medidas,
      permitePersonalizadas: permitePersonalizadas,
      estadosPorId: estados,
    );
  }

  OpcionPresentacion? opcionPorId(String id) {
    for (final opcion in presentaciones) {
      if (opcion.id == id) return opcion;
    }
    return null;
  }

  ConfiguracionMedida? medidaDe(FamiliaUnidad familia) {
    for (final configuracion in medidas) {
      if (configuracion.familia == familia) return configuracion;
    }
    return null;
  }

  /// Estado de una presentación en este rubro. Si es un id válido del
  /// catálogo global pero no está presente, es [EstadoVenta.inactiva].
  /// Lanza [ArgumentError] si el id no existe en el catálogo global.
  EstadoVenta estadoDe(String id) {
    final estado = _estadosPorId[id];
    if (estado != null) return estado;
    if (!CatalogoVentaGlobal.esIdValido(id)) {
      throw ArgumentError.value(id, 'id', 'La presentación no existe en el catálogo global.');
    }
    return EstadoVenta.inactiva;
  }

  bool get tieneOpcionales => _estadosPorId.values.contains(EstadoVenta.opcional);
  bool get tieneActivas => _estadosPorId.values.contains(EstadoVenta.activa);
  bool get tieneMedidasActivas => medidas.any((medida) => medida.activa);
}

// ═════════════════════════════════════════════════════════════════════════
// PresetsVenta
// ═════════════════════════════════════════════════════════════════════════
// Resuelve el preset de un rubro. Los rubros legacy ("Farmacia", "Ferretería")
// conservan su valor almacenado pero cargan el preset seguro de "Otros", igual
// que Categorias.obtener / UnidadesMedida.obtener. El nombre del rubro nunca
// se reescribe; la resolución solo decide QUÉ preset se usa.
// ═════════════════════════════════════════════════════════════════════════
class PresetsVenta {
  PresetsVenta._();

  static const Set<String> rubrosLegacy = {'Farmacia', 'Ferretería'};

  static final Map<String, PresetVentaRubro> porRubro = _construir();

  /// Presentación del catálogo global en un estado dado.
  /// [valoresBase] filtra los formatos; si es null se usan todos.
  static ({EstadoVenta estado, List<FormatoPresentacion> formatos}) _opt(
    String id,
    EstadoVenta estado, [
    List<int>? valoresBase,
  ]) => (
    estado: estado,
    formatos: CatalogoVentaGlobal.formatosDe(id, valoresBase: valoresBase),
  );

  static ConfiguracionMedida _medidaActiva(
    FamiliaUnidad familia, {
    required UnidadRegistrada unidadVisual,
    required int minimo,
    required int incremento,
    required List<int> rapidas,
    bool permiteCantidad = true,
    EstadoMonto monto = EstadoMonto.activo,
  }) => ConfiguracionMedida(
    familia: familia,
    unidadVisual: unidadVisual,
    minimoBase: minimo,
    incrementoBase: incremento,
    cantidadesRapidasBase: rapidas,
    permiteCantidad: permiteCantidad,
    monto: monto,
    activa: true,
  );

  static ConfiguracionMedida _medidaInactiva(FamiliaUnidad familia) {
    final configuracion = CatalogoVentaGlobal.medidaPorDefecto(familia);
    return ConfiguracionMedida(
      familia: configuracion.familia,
      unidadVisual: configuracion.unidadVisual,
      minimoBase: configuracion.minimoBase,
      incrementoBase: configuracion.incrementoBase,
      cantidadesRapidasBase: configuracion.cantidadesRapidasBase,
      permiteCantidad: configuracion.permiteCantidad,
      monto: configuracion.monto,
      activa: false,
    );
  }

  static ConfiguracionMedida _medidaInactivaPropia(
    FamiliaUnidad familia, {
    required UnidadRegistrada unidadVisual,
    required int minimo,
    required int incremento,
    required List<int> rapidas,
  }) => ConfiguracionMedida(
    familia: familia,
    unidadVisual: unidadVisual,
    minimoBase: minimo,
    incrementoBase: incremento,
    cantidadesRapidasBase: rapidas,
    permiteCantidad: true,
    monto: EstadoMonto.inactivo,
    activa: false,
  );

  static Map<String, PresetVentaRubro> _construir() {
    return {
      'Bodega': PresetVentaRubro.modelar(
        rubro: 'Bodega',
        categorias: const ['Abarrotes', 'Bebidas', 'Snacks', 'Limpieza', 'Cuidado personal'],
        presentaciones: {
          'unidad': _opt('unidad', EstadoVenta.obligatoria),
          'botella': _opt('botella', EstadoVenta.obligatoria,
              const [250, 500, 625, 650, 1000, 1500, 2000, 2500, 3000]),
          'lata': _opt('lata', EstadoVenta.obligatoria),
          'bolsa': _opt('bolsa', EstadoVenta.obligatoria),
          'caja': _opt('caja', EstadoVenta.obligatoria, const [6, 12, 24]),
          'paquete': _opt('paquete', EstadoVenta.obligatoria, const [6, 12, 24]),
        },
        medidas: [
          _medidaActiva(
            FamiliaUnidad.peso,
            unidadVisual: RegistroUnidades.kg,
            minimo: 100,
            incremento: 50,
            rapidas: const [250, 500, 750, 1000],
            monto: EstadoMonto.activo,
          ),
          _medidaActiva(
            FamiliaUnidad.volumen,
            unidadVisual: RegistroUnidades.L,
            minimo: 250,
            incremento: 250,
            rapidas: const [250, 500, 750, 1000],
            monto: EstadoMonto.opcional,
          ),
        ],
      ),
      'Restaurante': PresetVentaRubro.modelar(
        rubro: 'Restaurante',
        categorias: const ['Entradas', 'Platos principales', 'Bebidas', 'Postres', 'Combos'],
        presentaciones: {
          'unidad': _opt('unidad', EstadoVenta.obligatoria),
          'porcion': _opt('porcion', EstadoVenta.obligatoria),
          'plato': _opt('plato', EstadoVenta.obligatoria),
          'combo': _opt('combo', EstadoVenta.obligatoria),
          'vaso': _opt('vaso', EstadoVenta.obligatoria, const [250, 350, 500]),
          'botella': _opt('botella', EstadoVenta.obligatoria,
              const [500, 625, 1000, 1500, 2000, 2500, 3000]),
          'jarra': _opt('jarra', EstadoVenta.opcional),
        },
        medidas: [
          _medidaInactiva(FamiliaUnidad.peso),
          _medidaInactiva(FamiliaUnidad.volumen),
        ],
      ),
      'Ropa': PresetVentaRubro.modelar(
        rubro: 'Ropa',
        categorias: const ['Hombre', 'Mujer', 'Niños', 'Calzado', 'Accesorios'],
        presentaciones: {
          'unidad': _opt('unidad', EstadoVenta.obligatoria),
          'par': _opt('par', EstadoVenta.obligatoria),
          'conjunto': _opt('conjunto', EstadoVenta.obligatoria),
          'caja': _opt('caja', EstadoVenta.opcional),
          'paquete': _opt('paquete', EstadoVenta.opcional),
          'bolsa': _opt('bolsa', EstadoVenta.opcional),
        },
        medidas: [
          _medidaInactiva(FamiliaUnidad.longitud),
        ],
      ),
      'Accesorios y regalos': PresetVentaRubro.modelar(
        rubro: 'Accesorios y regalos',
        categorias: const ['Bisutería', 'Carteras', 'Peluches', 'Regalos', 'Detalles'],
        presentaciones: {
          'unidad': _opt('unidad', EstadoVenta.obligatoria),
          'par': _opt('par', EstadoVenta.obligatoria),
          'set': _opt('set', EstadoVenta.obligatoria),
          'juego': _opt('juego', EstadoVenta.obligatoria),
          'caja': _opt('caja', EstadoVenta.opcional),
          'paquete': _opt('paquete', EstadoVenta.opcional),
          'bolsa': _opt('bolsa', EstadoVenta.opcional),
        },
        medidas: [
          _medidaInactivaPropia(
            FamiliaUnidad.longitud,
            unidadVisual: RegistroUnidades.m,
            minimo: 100,
            incremento: 50,
            rapidas: const [100, 250, 500, 1000],
          ),
        ],
      ),
      'Belleza y cuidado personal': PresetVentaRubro.modelar(
        rubro: 'Belleza y cuidado personal',
        categorias: const ['Cabello', 'Rostro', 'Cuerpo', 'Maquillaje', 'Perfumería'],
        presentaciones: {
          'unidad': _opt('unidad', EstadoVenta.obligatoria),
          'frasco': _opt(
            'frasco',
            EstadoVenta.obligatoria,
            const [30, 50, 100, 120, 200, 250, 500],
          ),
          'botella': _opt(
            'botella',
            EstadoVenta.obligatoria,
            const [100, 200, 250, 500, 750, 1000],
          ),
          'pote': _opt('pote', EstadoVenta.obligatoria, const [30, 50, 100, 250, 500]),
          'tubo': _opt('tubo', EstadoVenta.obligatoria, const [30, 50, 100, 250, 500]),
          'sachet': _opt('sachet', EstadoVenta.obligatoria, const [5, 10, 15, 20]),
          'spray': _opt('spray', EstadoVenta.obligatoria),
        },
        medidas: [
          _medidaInactiva(FamiliaUnidad.peso),
          _medidaInactiva(FamiliaUnidad.volumen),
        ],
      ),
      'Otros': PresetVentaRubro.modelar(
        rubro: 'Otros',
        categorias: const ['Productos', 'Accesorios', 'Servicios relacionados', 'Otros'],
        presentaciones: {
          'unidad': _opt('unidad', EstadoVenta.obligatoria),
          'par': _opt('par', EstadoVenta.opcional),
          'set': _opt('set', EstadoVenta.opcional),
          'caja': _opt('caja', EstadoVenta.opcional),
          'paquete': _opt('paquete', EstadoVenta.opcional),
          'bolsa': _opt('bolsa', EstadoVenta.opcional),
        },
        medidas: [
          _medidaInactiva(FamiliaUnidad.peso),
          _medidaInactiva(FamiliaUnidad.volumen),
          _medidaInactiva(FamiliaUnidad.longitud),
          _medidaInactiva(FamiliaUnidad.area),
        ],
        permitePersonalizadas: true,
      ),
    };
  }

  /// Resuelve el preset del rubro. Los legacy ("Farmacia", "Ferretería")
  /// cargan el preset seguro de "Otros"; los desconocidos también, sin
  /// reescribir el rubro.
  static PresetVentaRubro obtener(String rubro) {
    final rubroEfectivo = rubrosLegacy.contains(rubro) ? 'Otros' : rubro;
    return porRubro[rubroEfectivo] ?? porRubro['Otros']!;
  }

  /// true si el rubro tiene un preset propio (los legacy se resuelven a
  /// "Otros" y no tienen datos propios).
  static bool esRubroConPresetPropio(String rubro) =>
      porRubro.containsKey(rubro);
}