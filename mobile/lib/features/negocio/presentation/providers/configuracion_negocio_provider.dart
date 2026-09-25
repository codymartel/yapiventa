import 'package:flutter/foundation.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import '../../data/negocio_repository.dart';
import '../../domain/models/zona_delivery.dart';
import '../../domain/models/categoria_personalizada.dart';
import '../../domain/models/horario_dia.dart';
import '../../domain/models/metodo_pago_tipo.dart';
import '../../domain/models/config_pago_metodo.dart';
import '../../domain/models/pais_telefono.dart';
import '../../domain/models/catalogo_venta/catalogo_venta_global.dart';
import '../../domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../domain/models/catalogo_venta/configuracion_medida.dart';
import '../../domain/models/catalogo_venta/formato_presentacion.dart';
import '../../domain/models/catalogo_venta/opcion_presentacion.dart';
import '../../domain/models/catalogo_venta/unidad_registrada.dart';
import '../../domain/models/catalogo_venta/preset_venta_rubro.dart';
import '../../../../domain/models/unidad_medida.dart';
import '../../../../domain/models/tipo_unidad.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfiguracionNegocioProvider
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Equivale a TODOS los `remember { mutableStateOf(...) }` de tu
// ConfiguracionNegocioScreen.kt, más la lógica de "puedeAvanzarPasoX" y
// las validaciones que antes vivían sueltas o dentro de `ejecutarGuardado`.
//
// QUÉ NO HACE:
// - NO habla con Firestore directo — eso lo delega a NegocioRepository.
// - NO valida formato de teléfono con "+51 fijo" — usa PaisTelefono,
//   donde el usuario elige su país (ver decisión tomada en la
//   conversación: se abandonó la validación estricta de Perú a favor
//   de un selector de país para toda Latinoamérica).
// - NO valida el RUC/documento tributario — se decidió dejarlo como
//   texto libre y opcional, sin formato específico de ningún país.
//
// CON QUÉ SE CONECTA:
// - Lo usan: los 4 widgets de paso (paso_negocio.dart, paso_catalogo.dart,
//   paso_logistica.dart, paso_pagos.dart) vía context.watch, y
//   configuracion_negocio_screen.dart para el stepper y navegación.
// ═════════════════════════════════════════════════════════════════════════

class ConfiguracionNegocioProvider extends ChangeNotifier {
  final NegocioRepository _repository;
  final String rubro;

  /// Resuelto en la sesión por AccesoProvider; evita releer users/{uid}.
  final String? negocioId;
  late final Set<String> _categoriasIniciales;
  late final Set<String> _unidadesIniciales;
  bool _disposed = false;

  /// Borrador en memoria del catálogo de venta (presentaciones + medidas).
  /// Se siembra con el preset del rubro y se reemplaza si la configuración
  /// guardada trae un [CatalogoVentaPersistido] (o se adapta desde unidades
  /// legacy). No se escribe en Firestore hasta `guardar()`.
  late CatalogoVentaPersistido _catalogoVenta;

  String? _errorCatalogo;
  String? get errorCatalogo => _errorCatalogo;

  ConfiguracionNegocioProvider({
    required this.rubro,
    this.negocioId,
    Map<String, dynamic>? configuracionInicial,
    NegocioRepository? repository,
  }) : _repository = repository ?? NegocioRepository() {
    // Las categorías, presentaciones y medidas del borrador se siembran con
    // el preset del rubro (PresetsVenta) como ÚNICA fuente: los mapas legacy
    // Categorias.porRubro / UnidadesMedida.porRubro ya no participan en el
    // poblado inicial (evita categorías y unidades fantasma como "Docena",
    // "Rollo" o "Par" que el mapa legacy no distingue por rubro).
    final preset = PresetsVenta.obtener(rubro);
    _categorias = List.of(preset.categorias);
    _categoriasPersonalizadas = const [];
    _unidadesMedida = _unidadesEspejoDelPreset(preset);
    _catalogoVenta = CatalogoVentaPersistido.desdePreset(preset);
    if (configuracionInicial != null && configuracionInicial.isNotEmpty) {
      _restaurarConfiguracion(configuracionInicial);
    }
    _categoriasIniciales = _categorias.toSet();
    _unidadesIniciales = _unidadesMedida.map((u) => u.nombre).toSet();
  }

  /// Espejo del preset en el formato legacy de [UnidadInfo].
  ///
  /// Única semilla de [_unidadesMedida] para un negocio NUEVO: delegates en
  /// [CatalogoVentaPersistido.unidadesEspejoDelPreset] para que la validación
  /// de dependencias de la capa de datos use exactamente el mismo conjunto de
  /// nombres. El campo `unidadesMedida` de Firestore se sigue escribiendo para
  /// que el flujo de productos y la compatibilidad de lectura sigan funcionando.
  static List<UnidadInfo> _unidadesEspejoDelPreset(PresetVentaRubro preset) =>
      CatalogoVentaPersistido.unidadesEspejoDelPreset(preset);

  void _restaurarConfiguracion(Map<String, dynamic> datos) {
    _nombreNegocio = datos['nombreNegocio'] as String? ?? '';
    _ruc = datos['ruc'] as String? ?? '';
    _linkFacebook = datos['facebook'] as String? ?? '';
    _linkTiktok = datos['tiktok'] as String? ?? '';
    _linkInstagram = datos['instagram'] as String? ?? '';
    _linkYoutube = datos['youtube'] as String? ?? '';

    final telefonoCompleto = datos['telefono'] as String? ?? '';
    _paisTelefono = paisesLatam.firstWhere(
      (pais) => telefonoCompleto.startsWith(pais.prefijo),
      orElse: () => _paisTelefono,
    );
    _telefono = telefonoCompleto
        .replaceFirst(_paisTelefono.prefijo, '')
        .replaceAll(RegExp(r'[^0-9]'), '');

    final direccionCompleta = datos['direccion'] as String? ?? '';
    const referenciaInicio = ' (Ref: ';
    final indiceReferencia = direccionCompleta.lastIndexOf(referenciaInicio);
    if (indiceReferencia != -1 && direccionCompleta.endsWith(')')) {
      _direccion = direccionCompleta.substring(0, indiceReferencia);
      _referencia = direccionCompleta.substring(
        indiceReferencia + referenciaInicio.length,
        direccionCompleta.length - 1,
      );
    } else {
      _direccion = direccionCompleta;
    }

    final categoriasGuardadas = (datos['categorias'] as List?)?.cast<String>();
    if (categoriasGuardadas != null) _categorias = categoriasGuardadas;

    _categoriasPersonalizadas = CategoriaPersonalizada.listaDesde(
      datos['categoriasPersonalizadas'],
    );

    final unidadesGuardadas = (datos['unidadesMedida'] as List?)
        ?.whereType<Map>()
        .map(
          (unidad) => UnidadInfo(
            nombre: unidad['nombre'] as String? ?? '',
            tipo: unidad['tipo'] == 'fraccionaria'
                ? TipoUnidad.fraccionaria
                : TipoUnidad.entera,
            fraccionesPermitidas:
                (unidad['fraccionesPermitidas'] as List?)?.cast<String>() ??
                const [],
            esOpcional: unidad['esOpcional'] as bool? ?? false,
          ),
        )
        .where((unidad) => unidad.nombre.isNotEmpty)
        .toList();
    if (unidadesGuardadas != null) _unidadesMedida = unidadesGuardadas;

    // Borrador de catálogo de venta: primero el guardado con esquema nuevo;
    // si no existe, se adapta lo que haya en unidadesMedida legacy (mismo
    // criterio que obtenerCatalogoVenta); si no hay nada que adaptar, queda
    // el preset del rubro sembrado en el constructor.
    //
    // Un negocio legacy (creado antes del preset, como el caso reportado
    // "dasdsad") trae unidades heredadas del mapa legacy en su documento y
    // SIN catalogoVenta: aquí se conservan en el catálogo lo que el registro
    // cerrado permite traducir y se marcan las demás para revisión. Esa
    // revisión es la migración de datos única que esos negocios necesitan;
    // los negocios nuevos jamás pasan por este camino.
    final catalogoGuardado = CatalogoVentaPersistido.desdeMapa(
      datos['catalogoVenta'],
    );
    if (catalogoGuardado != null) {
      _catalogoVenta = catalogoGuardado;
    }
    // Si catalogoGuardado es null, _catalogoVenta se queda tal como el
    // constructor lo calculó desde el preset (CatalogoVentaPersistido.desdePreset).
    // No reconstruir desde legacy aquí — eso es lo que rompía unidades como
    // "Par", "Docena", "Paquete", que no matchean el registro nuevo por nombre.

    _tieneDelivery = datos['delivery'] as bool? ?? false;
    _zonasDelivery
      ..clear()
      ..addAll(
        (datos['deliveryZonas'] as List?)?.whereType<Map>().map(
              (zona) => ZonaDelivery(
                zona: zona['zona'] as String? ?? '',
                costo: (zona['costo'] as num?)?.toString() ?? '',
              ),
            ) ??
            const [],
      );
    _horarios
      ..clear()
      ..addAll(
        (datos['horarios'] as List?)?.whereType<Map>().map(
              (horario) => HorarioDia(
                dia: horario['dia'] as String? ?? '',
                apertura: horario['apertura'] as String? ?? '',
                cierre: horario['cierre'] as String? ?? '',
                activo: horario['activo'] as bool? ?? false,
              ),
            ) ??
            const [],
      );

    final metodosActivos =
        (datos['metodosPago'] as List?)?.cast<String>() ?? const [];
    final configuracionesPago =
        (datos['configPagos'] as Map?)?.cast<String, dynamic>() ?? const {};
    _metodosPagoConfig = MetodoPagoTipo.todos.map((tipo) {
      final config = configuracionesPago[tipo.id] as Map? ?? const {};
      return ConfigPagoMetodo(
        metodoId: tipo.id,
        activo: metodosActivos.contains(tipo.id),
        numeroPago: config['numero'] as String? ?? '',
        descuentoActivo: config['descuentoActivo'] as bool? ?? false,
        tipoDescuento: config['tipoDescuento'] == 'monto_fijo'
            ? TipoDescuento.montoFijo
            : TipoDescuento.porcentaje,
        valorDescuento: (config['valorDescuento'] as num?)?.toString() ?? '',
        montoMinimo: (config['montoMinimo'] as num?)?.toString() ?? '',
      );
    }).toList();
  }

  // ── Paso actual del stepper ─────────────────────────────────────────
  int _pasoActual = 0;
  int get pasoActual => _pasoActual;
  static const totalPasos = 4;

  void irAPaso(int paso) {
    _pasoActual = paso;
    notifyListeners();
  }

  void siguiente() {
    if (_pasoActual < totalPasos - 1) _pasoActual++;
    notifyListeners();
  }

  void atras() {
    if (_pasoActual > 0) _pasoActual--;
    notifyListeners();
  }

  // ── Pestaña activa del paso Catálogo ──────────────────────────────────
  // El shell del dashboard la lee para mostrar la ayuda contextual de la
  // pestaña actual (0 Categorías, 1 Unidades de venta, 2 Medidas). Solo
  // guarda un índice: no escribe Firestore ni altera el borrador.
  int _catalogoPestana = 0;
  int get catalogoPestana => _catalogoPestana;

  void cambiarCatalogoPestana(int indice) {
    final acotado = indice.clamp(0, 2).toInt();
    if (acotado == _catalogoPestana) return;
    _catalogoPestana = acotado;
    notifyListeners();
  }

  // ── PASO 1: Datos del negocio ───────────────────────────────────────
  String _nombreNegocio = '';
  String get nombreNegocio => _nombreNegocio;
  set nombreNegocio(String v) {
    _nombreNegocio = v;
    notifyListeners();
  }

  // NUEVO — reemplaza el "+51" fijo del Kotlin por un país seleccionable.
  // Por defecto Perú, porque sigue siendo tu mercado principal, pero el
  // usuario puede cambiarlo.
  PaisTelefono _paisTelefono = paisesLatam.firstWhere(
    (p) => p.nombre == 'Perú',
  );
  PaisTelefono get paisTelefono => _paisTelefono;
  set paisTelefono(PaisTelefono v) {
    _paisTelefono = v;
    if (_telefono.length > v.digitosEsperados) {
      _telefono = _telefono.substring(0, v.digitosEsperados);
    }
    notifyListeners();
  }

  String _telefono = '';
  String get telefono => _telefono;
  set telefono(String v) {
    // Igual que tu Kotlin: solo dígitos, cortados a la cantidad
    // esperada del país actual (antes era fijo a 9, ahora depende del
    // país elegido).
    final soloDigitos = v.replaceAll(RegExp(r'[^0-9]'), '');
    _telefono = soloDigitos.length <= _paisTelefono.digitosEsperados
        ? soloDigitos
        : soloDigitos.substring(0, _paisTelefono.digitosEsperados);
    notifyListeners();
  }

  String _direccion = '';
  String get direccion => _direccion;
  set direccion(String v) {
    _direccion = v;
    notifyListeners();
  }

  String _referencia = '';
  String get referencia => _referencia;
  set referencia(String v) {
    _referencia = v;
    notifyListeners();
  }

  // RUC — texto libre y opcional, sin validar formato (decisión tomada:
  // no es una app de facturación formal).
  String _ruc = '';
  String get ruc => _ruc;
  set ruc(String v) {
    _ruc = v;
    notifyListeners();
  }

  String _linkFacebook = '';
  String get linkFacebook => _linkFacebook;
  set linkFacebook(String v) {
    _linkFacebook = v;
    notifyListeners();
  }

  String _linkTiktok = '';
  String get linkTiktok => _linkTiktok;
  set linkTiktok(String v) {
    _linkTiktok = v;
    notifyListeners();
  }

  String _linkInstagram = '';
  String get linkInstagram => _linkInstagram;
  set linkInstagram(String v) {
    _linkInstagram = v;
    notifyListeners();
  }

  String _linkYoutube = '';
  String get linkYoutube => _linkYoutube;
  set linkYoutube(String v) {
    _linkYoutube = v;
    notifyListeners();
  }

  // Equivale a tu `fun linkValido` — sin cambios de lógica.
  bool _linkValido(String link) {
    if (link.isEmpty) return true;
    if (!link.startsWith('https://')) return false;
    const sitiosProhibidos = [
      'onlyfans',
      'fansly',
      'pornhub',
      'xvideos',
      'cam4',
      'chaturbate',
      'adult',
    ];
    final lower = link.toLowerCase();
    return !sitiosProhibidos.any((s) => lower.contains(s));
  }

  bool get linksMalos =>
      !_linkValido(_linkFacebook) ||
      !_linkValido(_linkTiktok) ||
      !_linkValido(_linkInstagram) ||
      !_linkValido(_linkYoutube);

  // ── PASO 2: Catálogo (categorías + unidades) ────────────────────────
  late List<String> _categorias;
  List<String> get categorias => List.unmodifiable(_categorias);

  /// Categorías creadas por el usuario, cargadas desde
  /// `categoriasPersonalizadas`. Editar y eliminar llegan en etapas
  /// posteriores.
  late List<CategoriaPersonalizada> _categoriasPersonalizadas;
  List<CategoriaPersonalizada> get categoriasPersonalizadas =>
      List.unmodifiable(_categoriasPersonalizadas);

  /// Escribe la lista COMPLETA de personalizadas y solo entonces la aplica en
  /// memoria.
  ///
  /// El orden importa: primero Firestore, después el estado. Si fuera al revés,
  /// un fallo de red dejaría en pantalla una categoría que en la base no
  /// existe, y al recargar desaparecería sola. Por eso esta ruta notifica
  /// exactamente una vez y solo en el camino exitoso; los rechazos y el error
  /// de escritura dejan el estado intacto y reportan el motivo en
  /// [errorCatalogo].
  Future<bool> _persistirCategoriasPersonalizadas(
    String uid,
    List<CategoriaPersonalizada> actualizadas,
    String mensajeError,
  ) async {
    try {
      await _repository.guardarCategoriasPersonalizadas(
        uid,
        actualizadas,
        negocioId: negocioId,
      );
    } catch (_) {
      _errorCatalogo = mensajeError;
      return false;
    }

    _categoriasPersonalizadas = actualizadas;
    _errorCatalogo = null;
    notifyListeners();
    return true;
  }

  /// Crea una categoría personalizada y la persiste.
  ///
  /// La identidad es la clave canónica del nombre ([canonicalizarCategoria]),
  /// no el texto: escribir "  Dulces  " y "dulces" es la misma categoría y la
  /// segunda se rechaza.
  Future<bool> agregarCategoriaPersonalizada(String uid, String nombre) async {
    final nombreLimpio = nombre.trim();
    final clave = canonicalizarCategoria(nombreLimpio);
    if (clave.isEmpty) {
      _errorCatalogo = 'El nombre de la categoría no puede estar vacío.';
      return false;
    }
    if (_categoriasPersonalizadas.any((categoria) => categoria.clave == clave)) {
      _errorCatalogo = 'Ya existe una categoría con ese nombre.';
      return false;
    }

    final nueva = CategoriaPersonalizada(
      clave: clave,
      nombre: nombreLimpio,
      activa: true,
    );
    return _persistirCategoriasPersonalizadas(
      uid,
      [..._categoriasPersonalizadas, nueva],
      'No se pudo guardar la categoría. Revisa tu conexión.',
    );
  }

  /// Desactiva una categoría personalizada conservándola.
  ///
  /// Desactivar NO es eliminar: la categoría sigue en la lista con
  /// `activa: false` y por eso se sigue persistiendo. Renombrar y eliminar
  /// llegan en etapas posteriores.
  ///
  /// Una clave que no existe no es un error del usuario sino una operación
  /// imposible: devuelve `false` sin escribir, sin tocar el estado y sin
  /// notificar.
  Future<bool> desactivarCategoriaPersonalizada(
    String uid,
    String clave,
  ) async {
    final indice = _indiceCategoriaPersonalizada(clave);
    if (indice == -1) return false;

    final actualizada = [..._categoriasPersonalizadas];
    // copyWith y no una construcción nueva: la clave es la identidad y el
    // nombre es la etiqueta; esta operación no puede tocarlos.
    actualizada[indice] = actualizada[indice].copyWith(activa: false);

    return _persistirCategoriasPersonalizadas(
      uid,
      actualizada,
      'No se pudo desactivar la categoría. Revisa tu conexión.',
    );
  }

  /// Reactiva una categoría personalizada previamente desactivada.
  ///
  /// Es el inverso exacto de [desactivarCategoriaPersonalizada] y comparte su
  /// contrato: se busca por clave, la lista completa se persiste, y la
  /// memoria cambia y notifica solo si la escritura funcionó. Una clave
  /// inexistente devuelve `false` sin escribir nada.
  Future<bool> reactivarCategoriaPersonalizada(
    String uid,
    String clave,
  ) async {
    final indice = _indiceCategoriaPersonalizada(clave);
    if (indice == -1) return false;

    final actualizada = [..._categoriasPersonalizadas];
    actualizada[indice] = actualizada[indice].copyWith(activa: true);

    return _persistirCategoriasPersonalizadas(
      uid,
      actualizada,
      'No se pudo reactivar la categoría. Revisa tu conexión.',
    );
  }

  /// Índice de una personalizada por su clave canónica, o -1 si no existe.
  /// La clave es la identidad: buscar por nombre haría que un cambio de
  /// etiqueta cambiara a qué categoría apunta una operación.
  int _indiceCategoriaPersonalizada(String clave) =>
      _categoriasPersonalizadas.indexWhere(
        (categoria) => categoria.clave == clave,
      );

  /// Renombra una categoría personalizada conservando su identidad.
  ///
  /// La clave NO se recalcula: los productos la referencian, y rederivarla
  /// dejaría la categoría apuntando a un lado viejo. Renombrar es cambiar la
  /// etiqueta, nunca cambiar quién es. Por eso tampoco se toca `activa`.
  ///
  /// El nombre nuevo sí tiene que ser legítimo: no vacío, y no puede
  /// canon coincidir con otra personalizada, porque dos categorías con la misma
  /// clave serían la misma categoría con dos etiquetas.
  Future<bool> renombrarCategoriaPersonalizada(
    String uid,
    String clave,
    String nombreNuevo,
  ) async {
    final indice = _indiceCategoriaPersonalizada(clave);
    if (indice == -1) return false;

    final nombreLimpio = nombreNuevo.trim();
    if (canonicalizarCategoria(nombreLimpio).isEmpty) {
      _errorCatalogo = 'El nombre de la categoría no puede estar vacío.';
      return false;
    }
    final colisiona = _categoriasPersonalizadas.any(
      (categoria) =>
          categoria.clave != clave &&
          categoria.clave == canonicalizarCategoria(nombreLimpio),
    );
    if (colisiona) {
      _errorCatalogo = 'Ya existe una categoría con ese nombre.';
      return false;
    }

    // copyWith y no CategoriaPersonalizada.renombrar: aquel reconstruye la
    // categoría y revierte `activa` a true, lo que reactivaría en silencio
    // una categoría que el negocio tenía desactivada.
    final actualizada = [..._categoriasPersonalizadas];
    actualizada[indice] = actualizada[indice].copyWith(nombre: nombreLimpio);

    return _persistirCategoriasPersonalizadas(
      uid,
      actualizada,
      'No se pudo renombrar la categoría. Revisa tu conexión.',
    );
  }

  void agregarCategoria(String nombre) {
    if (_esCategoriaDuplicada(nombre)) return;
    _categorias.add(nombre);
    notifyListeners();
  }

  void editarCategoria(int index, String nuevoNombre) {
    if (_esCategoriaDuplicada(nuevoNombre, exceptoIndex: index)) return;
    _categorias[index] = nuevoNombre;
    notifyListeners();
  }

  void eliminarCategoria(int index) {
    _categorias.removeAt(index);
    notifyListeners();
  }

  /// Detección de duplicados por nombre normalizado (trim + minúsculas);
  /// [exceptoIndex] ignora la propia categoría al renombrar.
  bool _esCategoriaDuplicada(String nombre, {int? exceptoIndex}) {
    final normalizado = nombre.trim().toLowerCase();
    if (normalizado.isEmpty) return false;
    for (var i = 0; i < _categorias.length; i++) {
      if (i != exceptoIndex &&
          _categorias[i].trim().toLowerCase() == normalizado) {
        return true;
      }
    }
    return false;
  }

  bool categoriaActiva(String nombre) => _categorias.contains(nombre);

  void desactivarCategoria(String nombre) {
    if (_categorias.length <= 1) return;
    _categorias.remove(nombre);
    notifyListeners();
  }

  /// Consulta de solo lectura: dice si algún producto usa la categoría.
  /// Con negocioId inyectado no necesita leer users/{uid}; si no hay
  /// negocioId aún no puede haber productos asociados.
  Future<bool> categoriaTieneProductos(String nombre) async {
    final id = negocioId?.trim();
    if (id == null || id.isEmpty) return false;
    return _repository.existenProductosDependientes(
      uid: '',
      negocioId: id,
      categorias: [nombre],
      unidades: const [],
    );
  }

  /// Unidades en formato legacy. DESTINO: compatibilidad de lectura.
  ///
  /// Para negocios NUEVOS es el espejo del preset ([_unidadesEspejoDelPreset]);
  /// para negocios legacy se restaura tal cual del documento guardado. La UI
  /// de "Unidades de venta"/"Medidas" ya no la usa (vive en presentaciones y
  /// medidas de [_catalogoVenta]); `guardar()` la escribe en Firestore solo
  /// porque el flujo de productos y los filtros legacy aún la leen.
  late List<UnidadInfo> _unidadesMedida;
  List<UnidadInfo> get unidadesMedida => List.unmodifiable(_unidadesMedida);
  List<UnidadInfo> get unidadesPredefinidas =>
      List.unmodifiable(UnidadesMedida.obtener(rubro));

  bool unidadPredefinidaActiva(String nombre) =>
      _unidadesMedida.any((unidad) => unidad.nombre == nombre);

  bool unidadPredefinida(UnidadInfo unidad) => unidadesPredefinidas.any(
    (predefinida) => predefinida.nombre == unidad.nombre,
  );

  bool unidadBaseProtegida(String nombre) {
    return const {
      'unidad',
      'g',
      'kg',
      'ml',
      'l',
      // Compatibilidad con configuraciones guardadas antes del nombre "L".
      'litro (l)',
    }.contains(nombre.trim().toLowerCase());
  }

  void establecerUnidadPredefinidaActiva(
    UnidadInfo unidad, {
    required bool activa,
  }) {
    final predefinida = unidadesPredefinidas.where(
      (opcion) => opcion.nombre == unidad.nombre,
    );
    if (predefinida.isEmpty) return;

    final index = _unidadesMedida.indexWhere(
      (opcion) => opcion.nombre == unidad.nombre,
    );
    if (activa && index == -1) {
      _unidadesMedida.add(predefinida.first);
    } else if (!activa && index != -1) {
      _unidadesMedida.removeAt(index);
    } else {
      return;
    }
    notifyListeners();
  }

  void agregarUnidad(UnidadInfo unidad) {
    if (_unidadesMedida.any(
      (actual) =>
          actual.nombre.trim().toLowerCase() ==
          unidad.nombre.trim().toLowerCase(),
    )) {
      return;
    }
    _unidadesMedida.add(unidad);
    notifyListeners();
  }

  void editarUnidad(int index, UnidadInfo unidad) {
    final actual = _unidadesMedida[index];
    if ((unidadPredefinida(actual) || unidadBaseProtegida(actual.nombre)) &&
        actual.nombre != unidad.nombre) {
      return;
    }
    if (_unidadesMedida.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.nombre.trim().toLowerCase() ==
              unidad.nombre.trim().toLowerCase(),
    )) {
      return;
    }
    _unidadesMedida[index] = unidad;
    notifyListeners();
  }

  void eliminarUnidad(int index) {
    final unidad = _unidadesMedida[index];
    if (unidadPredefinida(unidad) || unidadBaseProtegida(unidad.nombre)) return;
    _unidadesMedida.removeAt(index);
    notifyListeners();
  }

  // ── PASO 2b: Catálogo de venta (presentaciones + medidas) ────────────
  // Borrador en memoria (CatalogoVentaPersistido) con reglas de edición.
  // Las presentaciones del catálogo global tienen NOMBRE e ID estables
  // (solo cambian activa/formatos); las personalizadas se crean y renombran.
  // Los formatos se comparan normalizados (1000 ml y 1 L son el mismo).
  // Las medidas viven en unidad base y sus ediciones se validan con
  // ConfiguracionMedida.validar antes de aplicarse.

  List<OpcionPresentacion> get presentaciones => _catalogoVenta.presentaciones;
  List<MedidaVentaPersistida> get medidas => _catalogoVenta.medidas;

  /// Borrador completo (presentaciones + medidas).
  CatalogoVentaPersistido get catalogoVenta => _catalogoVenta;

  // ── Resumen del catálogo para la integración visual final ─────────────
  // Cantidades de solo lectura que alimentan el resumen "antes de avanzar"
  // del paso Catálogo y sus pruebas de integración.
  int get categoriasActivas => _categorias.length;
  int get presentacionesActivas => _catalogoVenta.presentaciones
      .where((presentacion) => presentacion.activa)
      .length;
  int get medidasActivas =>
      _catalogoVenta.medidas.where((medida) => medida.activa).length;
  int get totalFormatos => _catalogoVenta.presentaciones.fold(
    0,
    (total, presentacion) => total + presentacion.formatos.length,
  );
  int get totalCantidadesRapidas => _catalogoVenta.medidas.fold(
    0,
    (total, medida) => total + medida.cantidadesRapidasBase.length,
  );

  /// Nombres de las medidas que quedaron pendientes de revisión (bloquean
  /// el guardado). El resumen las muestra como errores pendientes.
  List<String> get medidasPendientesRevision => _catalogoVenta.medidas
      .where((medida) => medida.requiereRevision)
      .map((medida) => medida.nombre)
      .toList();

  OpcionPresentacion? presentacionPorId(String id) {
    for (final presentacion in _catalogoVenta.presentaciones) {
      if (presentacion.id == id) return presentacion;
    }
    return null;
  }

  bool presentacionActiva(String id) => presentacionPorId(id)?.activa ?? false;
  bool presentacionObligatoria(String id) =>
      presentacionPorId(id)?.obligatoria ?? false;
  bool presentacionEsPersonalizada(String id) =>
      presentacionPorId(id)?.personalizada ?? false;

  /// Solo el rubro "Otros" admite presentaciones personalizadas.
  bool get puedeCrearPresentacionesPersonalizadas =>
      PresetsVenta.obtener(rubro).permitePersonalizadas;

  MedidaVentaPersistida? medidaDe(FamiliaUnidad familia) {
    for (final medida in _catalogoVenta.medidas) {
      if (medida.familia == familia) return medida;
    }
    return null;
  }

  bool medidaActiva(FamiliaUnidad familia) =>
      medidaDe(familia)?.activa ?? false;

  void limpiarErrorCatalogo() {
    if (_errorCatalogo == null) return;
    _errorCatalogo = null;
    notifyListeners();
  }

  void _rechazarCatalogo(String mensaje) {
    _errorCatalogo = mensaje;
    notifyListeners();
  }

  void _reemplazarCatalogo(CatalogoVentaPersistido nuevo) {
    _catalogoVenta = nuevo;
    _errorCatalogo = null;
    notifyListeners();
  }

  void _reemplazarPresentacion(int index, OpcionPresentacion nueva) {
    final presentaciones = [..._catalogoVenta.presentaciones];
    presentaciones[index] = nueva;
    _reemplazarCatalogo(
      CatalogoVentaPersistido(
        version: _catalogoVenta.version,
        presentaciones: presentaciones,
        medidas: _catalogoVenta.medidas,
      ),
    );
  }

  void _reemplazarMedida(int index, MedidaVentaPersistida nueva) {
    final medidas = [..._catalogoVenta.medidas];
    medidas[index] = nueva;
    _reemplazarCatalogo(
      CatalogoVentaPersistido(
        version: _catalogoVenta.version,
        presentaciones: _catalogoVenta.presentaciones,
        medidas: medidas,
      ),
    );
  }

  int _indicePresentacion(String id) =>
      _catalogoVenta.presentaciones.indexWhere((p) => p.id == id);

  bool _tituloPresentacionOcupado(String nombre, {String? exceptoId}) {
    final normalizado = nombre.trim().toLowerCase();
    return _catalogoVenta.presentaciones.any(
      (p) => p.id != exceptoId && p.nombre.trim().toLowerCase() == normalizado,
    );
  }

  String _siguienteIdPersonalizado() {
    final usados = _catalogoVenta.presentaciones.map((p) => p.id).toSet();
    var i = 1;
    while (usados.contains('personalizada-$i')) {
      i++;
    }
    return 'personalizada-$i';
  }

  /// Activa o desactiva una presentación. Las obligatorias no se desactivan.
  void establecerPresentacionActiva(String id, {required bool activa}) {
    final index = _indicePresentacion(id);
    if (index == -1) {
      _rechazarCatalogo('La presentación no existe en el catálogo.');
      return;
    }
    final actual = _catalogoVenta.presentaciones[index];
    if (!activa && actual.obligatoria) {
      _rechazarCatalogo(
        'No puedes desactivar ${actual.nombre}: es obligatoria para $rubro.',
      );
      return;
    }
    if (actual.activa == activa) return;
    _reemplazarPresentacion(
      index,
      OpcionPresentacion(
        id: actual.id,
        nombre: actual.nombre,
        formatos: actual.formatos,
        activa: activa,
        obligatoria: actual.obligatoria,
        personalizada: actual.personalizada,
      ),
    );
  }

  /// Agrega una presentación personalizada con sus formatos. Solo en rubros
  /// que permiten personalizadas ("Otros"). Rechaza nombres ya usados y
  /// formatos duplicados normalizados.
  void agregarPresentacionPersonalizada({
    required String nombre,
    required List<FormatoPresentacion> formatos,
  }) {
    if (!puedeCrearPresentacionesPersonalizadas) {
      _rechazarCatalogo('$rubro no admite presentaciones personalizadas.');
      return;
    }
    final titulo = nombre.trim();
    if (titulo.isEmpty) {
      _rechazarCatalogo('El nombre de la presentación no puede estar vacío.');
      return;
    }
    if (formatos.isEmpty) {
      _rechazarCatalogo('La presentación debe tener al menos un formato.');
      return;
    }
    if (_tituloPresentacionOcupado(titulo)) {
      _rechazarCatalogo('Ya existe una presentación con ese nombre.');
      return;
    }
    final opcion = OpcionPresentacion(
      id: _siguienteIdPersonalizado(),
      nombre: titulo,
      formatos: formatos,
      activa: true,
      personalizada: true,
    );
    final error = opcion.validar();
    if (error != null) {
      _rechazarCatalogo(error);
      return;
    }
    _reemplazarCatalogo(
      CatalogoVentaPersistido(
        version: _catalogoVenta.version,
        presentaciones: [..._catalogoVenta.presentaciones, opcion],
        medidas: _catalogoVenta.medidas,
      ),
    );
  }

  /// Renombra solo presentaciones personalizadas (las del catálogo global
  /// tienen nombre fijo). Rechaza nombres ya usados.
  void renombrarPresentacion(String id, String nuevoNombre) {
    final index = _indicePresentacion(id);
    if (index == -1) {
      _rechazarCatalogo('La presentación no existe en el catálogo.');
      return;
    }
    final actual = _catalogoVenta.presentaciones[index];
    if (!actual.personalizada) {
      _rechazarCatalogo('Solo las presentaciones personalizadas se renombran.');
      return;
    }
    final titulo = nuevoNombre.trim();
    if (titulo.isEmpty) {
      _rechazarCatalogo('El nombre de la presentación no puede estar vacío.');
      return;
    }
    if (_tituloPresentacionOcupado(titulo, exceptoId: id)) {
      _rechazarCatalogo('Ya existe una presentación con ese nombre.');
      return;
    }
    _reemplazarPresentacion(
      index,
      OpcionPresentacion(
        id: actual.id,
        nombre: titulo,
        formatos: actual.formatos,
        activa: actual.activa,
        obligatoria: actual.obligatoria,
        personalizada: actual.personalizada,
      ),
    );
  }

  /// Elimina una presentación que no sea obligatoria (global opcional o
  /// personalizada).
  void eliminarPresentacion(String id) {
    final index = _indicePresentacion(id);
    if (index == -1) {
      _rechazarCatalogo('La presentación no existe en el catálogo.');
      return;
    }
    final actual = _catalogoVenta.presentaciones[index];
    if (actual.obligatoria) {
      _rechazarCatalogo(
        'No puedes eliminar ${actual.nombre}: es obligatoria para $rubro.',
      );
      return;
    }
    final presentaciones = [..._catalogoVenta.presentaciones]..removeAt(index);
    _reemplazarCatalogo(
      CatalogoVentaPersistido(
        version: _catalogoVenta.version,
        presentaciones: presentaciones,
        medidas: _catalogoVenta.medidas,
      ),
    );
  }

  /// Agrega un formato a una presentación. Para las del catálogo global solo
  /// admite formatos permitidos; rechaza duplicados equivalentes (la misma
  /// cantidad normalizada, p. ej. 1000 ml y 1 L).
  void agregarFormato(String id, FormatoPresentacion formato) {
    final index = _indicePresentacion(id);
    if (index == -1) {
      _rechazarCatalogo('La presentación no existe en el catálogo.');
      return;
    }
    final actual = _catalogoVenta.presentaciones[index];
    if (!actual.personalizada &&
        !CatalogoVentaGlobal.esFormatoPermitido(id, formato)) {
      _rechazarCatalogo(
        'El formato ${formato.etiqueta} no está permitido para '
        '${actual.nombre}.',
      );
      return;
    }
    if (actual.formatos.any(
      (formatoActual) => formatoActual.esMismoFormato(formato),
    )) {
      _rechazarCatalogo(
        '${formato.etiqueta} ya es un formato de ${actual.nombre}.',
      );
      return;
    }
    _reemplazarPresentacion(
      index,
      OpcionPresentacion(
        id: actual.id,
        nombre: actual.nombre,
        formatos: [...actual.formatos, formato],
        activa: actual.activa,
        obligatoria: actual.obligatoria,
        personalizada: actual.personalizada,
      ),
    );
  }

  /// Elimina un formato por cantidad normalizada. Nunca deja una
  /// presentación sin formatos.
  void eliminarFormato(String id, FormatoPresentacion formato) {
    final index = _indicePresentacion(id);
    if (index == -1) {
      _rechazarCatalogo('La presentación no existe en el catálogo.');
      return;
    }
    final actual = _catalogoVenta.presentaciones[index];
    final indiceFormato = actual.formatos.indexWhere(
      (formatoActual) => formatoActual.esMismoFormato(formato),
    );
    if (indiceFormato == -1) {
      _rechazarCatalogo(
        '${formato.etiqueta} no es un formato de ${actual.nombre}.',
      );
      return;
    }
    if (actual.formatos.length <= 1) {
      _rechazarCatalogo(
        'No puedes quitar el único formato de ${actual.nombre}.',
      );
      return;
    }
    final formatos = [...actual.formatos]..removeAt(indiceFormato);
    _reemplazarPresentacion(
      index,
      OpcionPresentacion(
        id: actual.id,
        nombre: actual.nombre,
        formatos: formatos,
        activa: actual.activa,
        obligatoria: actual.obligatoria,
        personalizada: actual.personalizada,
      ),
    );
  }

  /// Activa o desactiva una medida (venta por peso, volumen...).
  void establecerMedidaActiva(FamiliaUnidad familia, {required bool activa}) {
    final index = _indiceMedida(familia);
    if (index == -1) {
      _rechazarCatalogo('No hay una medida configurada para $familia.');
      return;
    }
    final actual = _catalogoVenta.medidas[index];
    if (actual.activa == activa) return;
    _reemplazarMedida(index, _medidaEditada(actual, activa: activa));
  }

  /// Edita el mínimo de venta (en la unidad base de la familia).
  void editarMinimoBase(FamiliaUnidad familia, int minimoBase) {
    _editarMedidaValidando(familia, minimo: minimoBase);
  }

  /// Edita el incremento de venta (en la unidad base de la familia).
  void editarIncrementoBase(FamiliaUnidad familia, int incrementoBase) {
    _editarMedidaValidando(familia, incremento: incrementoBase);
  }

  /// Reemplaza las cantidades rápidas de la medida (en unidad base).
  void editarCantidadesRapidasBase(
    FamiliaUnidad familia,
    List<int> cantidades,
  ) {
    _editarMedidaValidando(familia, rapidas: cantidades);
  }

  /// Cambia la unidad habitual que ve el cliente (kg, L, cm, m²...).
  /// El dropdown del editor solo ofrece unidades de la familia, así que una
  /// unidad inválida se rechaza aquí mismo (defensivo).
  void editarUnidadVisual(FamiliaUnidad familia, UnidadRegistrada unidad) {
    _editarMedidaValidando(familia, unidadVisual: unidad);
  }

  /// Activa/desactiva la venta por cantidad en esa medida.
  void establecerPermiteCantidad(
    FamiliaUnidad familia, {
    required bool permite,
  }) {
    _editarMedidaValidando(familia, permiteCantidad: permite);
  }

  /// Activa/desactiva la venta por monto en esa medida.
  void establecerPermiteMonto(FamiliaUnidad familia, {required bool permite}) {
    _editarMedidaValidando(familia, permiteMonto: permite);
  }

  int _indiceMedida(FamiliaUnidad familia) =>
      _catalogoVenta.medidas.indexWhere((medida) => medida.familia == familia);

  /// Valida la edición contra [ConfiguracionMedida.validar] y reemplaza la
  /// medida si todo es consistente (mínimo/incremento positivos, rápidas
  /// fieles al mínimo+incremento, y al menos venta por cantidad o por monto).
  void _editarMedidaValidando(
    FamiliaUnidad familia, {
    UnidadRegistrada? unidadVisual,
    int? minimo,
    int? incremento,
    List<int>? rapidas,
    bool? permiteCantidad,
    bool? permiteMonto,
  }) {
    final index = _indiceMedida(familia);
    if (index == -1) {
      _rechazarCatalogo('No hay una medida configurada para $familia.');
      return;
    }
    final actual = _catalogoVenta.medidas[index];
    if (actual.familia == null ||
        actual.unidadBase == null ||
        actual.unidadVisual == null) {
      _rechazarCatalogo(
        '${actual.nombre} requiere revisión: primero resuélvela para '
        'poder editarla.',
      );
      return;
    }
    final unidadVisualFinal = unidadVisual ?? actual.unidadVisual!;
    final minimoFinal = minimo ?? actual.minimoBase;
    final incrementoFinal = incremento ?? actual.incrementoBase;
    final rapidasFinales = rapidas ?? actual.cantidadesRapidasBase;
    final permiteCantidadFinal = permiteCantidad ?? actual.permiteCantidad;
    final permiteMontoFinal = permiteMonto ?? actual.permiteMonto;

    final error = ConfiguracionMedida.validar(
      familia: actual.familia!,
      unidadVisual: unidadVisualFinal,
      minimoBase: minimoFinal,
      incrementoBase: incrementoFinal,
      cantidadesRapidasBase: rapidasFinales,
      permiteCantidad: permiteCantidadFinal,
      monto: permiteMontoFinal ? EstadoMonto.activo : EstadoMonto.inactivo,
    );
    if (error != null) {
      _rechazarCatalogo(error);
      return;
    }
    _reemplazarMedida(
      index,
      _medidaEditada(
        actual,
        unidadVisual: unidadVisualFinal,
        minimo: minimoFinal,
        incremento: incrementoFinal,
        rapidas: rapidasFinales,
        permiteCantidad: permiteCantidadFinal,
        permiteMonto: permiteMontoFinal,
      ),
    );
  }

  /// Reconstruye una [MedidaVentaPersistida] reemplazando los campos dados.
  MedidaVentaPersistida _medidaEditada(
    MedidaVentaPersistida actual, {
    bool? activa,
    UnidadRegistrada? unidadVisual,
    int? minimo,
    int? incremento,
    List<int>? rapidas,
    bool? permiteCantidad,
    bool? permiteMonto,
  }) {
    return MedidaVentaPersistida(
      id: actual.id,
      nombre: actual.nombre,
      familia: actual.familia,
      unidadBase: actual.unidadBase,
      unidadVisual: unidadVisual ?? actual.unidadVisual,
      minimoBase: minimo ?? actual.minimoBase,
      incrementoBase: incremento ?? actual.incrementoBase,
      cantidadesRapidasBase: rapidas ?? actual.cantidadesRapidasBase,
      permiteCantidad: permiteCantidad ?? actual.permiteCantidad,
      permiteMonto: permiteMonto ?? actual.permiteMonto,
      activa: activa ?? actual.activa,
      obligatoria: actual.obligatoria,
      requiereRevision: actual.requiereRevision,
    );
  }

  // ── PASO 3: Logística (delivery + horarios) ─────────────────────────
  bool _tieneDelivery = false;
  bool get tieneDelivery => _tieneDelivery;
  set tieneDelivery(bool v) {
    _tieneDelivery = v;
    notifyListeners();
  }

  final List<ZonaDelivery> _zonasDelivery = [];
  List<ZonaDelivery> get zonasDelivery => List.unmodifiable(_zonasDelivery);

  void agregarZona(ZonaDelivery zona) {
    _zonasDelivery.add(zona);
    notifyListeners();
  }

  void editarZona(int index, ZonaDelivery zona) {
    _zonasDelivery[index] = zona;
    notifyListeners();
  }

  void eliminarZona(int index) {
    _zonasDelivery.removeAt(index);
    notifyListeners();
  }

  final List<HorarioDia> _horarios = [];
  List<HorarioDia> get horarios => List.unmodifiable(_horarios);

  void agregarHorario(HorarioDia horario) {
    _horarios.add(horario);
    notifyListeners();
  }

  void editarHorario(int index, HorarioDia horario) {
    _horarios[index] = horario;
    notifyListeners();
  }

  void eliminarHorario(int index) {
    _horarios.removeAt(index);
    notifyListeners();
  }

  // ── PASO 4: Métodos de pago ──────────────────────────────────────────
  List<ConfigPagoMetodo> _metodosPagoConfig = MetodoPagoTipo.todos
      .map((tipo) => ConfigPagoMetodo(metodoId: tipo.id))
      .toList();
  List<ConfigPagoMetodo> get metodosPagoConfig =>
      List.unmodifiable(_metodosPagoConfig);

  void actualizarMetodoPago(
    int index,
    ConfigPagoMetodo Function(ConfigPagoMetodo) actualizar,
  ) {
    _metodosPagoConfig = List.of(_metodosPagoConfig);
    _metodosPagoConfig[index] = actualizar(_metodosPagoConfig[index]);
    notifyListeners();
  }

  // ── Validaciones reactivas (equivalen a las `val` de tu Kotlin) ─────
  bool get faltaNombre => _nombreNegocio.trim().length < 3;
  bool get faltaTelefono => _telefono.length != _paisTelefono.digitosEsperados;
  bool get faltaDireccion => _direccion.trim().length < 5;
  bool get faltaReferencia => _referencia.trim().length < 5;
  bool get faltaCategoria => _categorias.isEmpty;
  bool get faltaUnidad => _unidadesMedida.isEmpty;
  bool get faltaZonas => _tieneDelivery && _zonasDelivery.isEmpty;

  bool get puedeAvanzarPaso0 =>
      !faltaNombre &&
      !faltaTelefono &&
      !faltaDireccion &&
      !faltaReferencia &&
      !linksMalos;
  bool get puedeAvanzarPaso1 =>
      !faltaCategoria && !faltaUnidad && medidasPendientesRevision.isEmpty;
  bool get puedeAvanzarPaso2 => !faltaZonas;
  bool get puedeAvanzarPaso3 =>
      true; // pagos son opcionales, igual que en Kotlin

  bool get camposCompletos =>
      puedeAvanzarPaso0 && puedeAvanzarPaso1 && puedeAvanzarPaso2;

  bool get puedeAvanzarActual {
    switch (_pasoActual) {
      case 0:
        return puedeAvanzarPaso0;
      case 1:
        return puedeAvanzarPaso1;
      case 2:
        return puedeAvanzarPaso2;
      case 3:
        return camposCompletos;
      default:
        return false;
    }
  }

  // ── Guardado final ───────────────────────────────────────────────────
  bool _guardando = false;
  bool get guardando => _guardando;

  String? _errorValidacion;
  String? get errorValidacion => _errorValidacion;

  void limpiarError() {
    _errorValidacion = null;
    notifyListeners();
  }

  /// Equivale a tu `ejecutarGuardado`, sin la parte de validación de RUC
  /// peruano (ya no aplica) ni el "+51" fijo — usa el país seleccionado.
  Future<bool> guardar(String uid) async {
    if (_guardando) return false;

    final medidasPendientes = _catalogoVenta.medidas
        .where((medida) => medida.requiereRevision)
        .map((medida) => medida.nombre)
        .toList();
    if (medidasPendientes.isNotEmpty) {
      _errorValidacion =
          'El catálogo tiene medidas pendientes de revisión '
          '(${medidasPendientes.join(', ')}): revísalas antes de guardar.';
      notifyListeners();
      return false;
    }

    if (uid.trim().isEmpty || !camposCompletos) {
      _errorValidacion =
          'Completa los datos obligatorios antes de guardar la configuración.';
      notifyListeners();
      return false;
    }
    if (linksMalos) {
      _errorValidacion = 'Los links de redes deben empezar con https://';
      notifyListeners();
      return false;
    }
    if (_tieneDelivery && _zonasDelivery.isEmpty) {
      _errorValidacion = 'Agrega al menos una zona de delivery.';
      notifyListeners();
      return false;
    }
    for (final config in _metodosPagoConfig) {
      final tipo = MetodoPagoTipo.porId(config.metodoId);
      if (tipo == null) continue;
      if (config.activo && tipo.permiteNumeroPersonalizado) {
        final digitos = config.numeroPago.replaceAll(RegExp(r'[^0-9]'), '');
        if (digitos.length != 9) {
          _errorValidacion =
              'El número de ${tipo.nombre} debe tener exactamente 9 dígitos.';
          notifyListeners();
          return false;
        }
      }
      if (config.activo && tipo.permiteDescuento && config.descuentoActivo) {
        if (config.valorDescuento.isEmpty) {
          _errorValidacion =
              'Ingresa un valor de descuento para ${tipo.nombre}.';
          notifyListeners();
          return false;
        }
        if (!valorDescuentoValido(
          config.valorDescuento,
          config.tipoDescuento,
        )) {
          _errorValidacion = config.tipoDescuento == TipoDescuento.porcentaje
              ? 'El descuento de ${tipo.nombre} debe estar entre 0% y 100%.'
              : 'El descuento de ${tipo.nombre} debe ser un monto válido.';
          notifyListeners();
          return false;
        }
      }
    }

    final baseSlug = _generarSlug(_nombreNegocio);
    final sufijo = _telefono.length >= 4
        ? _telefono.substring(_telefono.length - 4)
        : _telefono;
    final slugFinal = '$baseSlug-$sufijo';

    _errorValidacion = null;
    _guardando = true;
    notifyListeners();

    try {
      final categoriasEliminadas = _categoriasIniciales
          .difference(_categorias.toSet())
          .toList();
      final unidadesEliminadas = _unidadesIniciales
          .difference(_unidadesMedida.map((u) => u.nombre).toSet())
          .toList();
      final hayProductosAfectados =
          (categoriasEliminadas.isNotEmpty || unidadesEliminadas.isNotEmpty) &&
          await _repository.existenProductosDependientes(
            uid: uid,
            negocioId: negocioId,
            categorias: categoriasEliminadas,
            unidades: unidadesEliminadas,
          );
      if (hayProductosAfectados) {
        _errorValidacion =
            'Hay productos que usan categorías o unidades eliminadas. '
            'Revísalos primero; no se borró ningún dato.';
        return false;
      }
      await _repository.guardarConfiguracionNegocio(
        uid: uid,
        negocioId: negocioId,
        rubro: rubro,
        nombreNegocio: _nombreNegocio,
        slug: slugFinal,
        telefonoCompleto: '${_paisTelefono.prefijo}$_telefono',
        direccionCompleta: '${_direccion.trim()} (Ref: ${_referencia.trim()})',
        ruc: _ruc,
        facebook: _linkFacebook,
        tiktok: _linkTiktok,
        instagram: _linkInstagram,
        youtube: _linkYoutube,
        categorias: _categorias,
        unidadesMedida: _unidadesMedida,
        catalogoVenta: _catalogoVenta,
        tieneDelivery: _tieneDelivery,
        zonasDelivery: _zonasDelivery,
        horarios: _horarios,
        metodosPagoConfig: _metodosPagoConfig,
      );
      return true;
    } catch (e) {
      _errorValidacion = 'Error de conexión con Firebase.';
      return false;
    } finally {
      _guardando = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Equivale a tu `fun generarSlug` — sin cambios de lógica, adaptado a
  // Dart (Kotlin usaba Normalizer de Java para quitar tildes).
  String _generarSlug(String input) {
    const conTilde = 'áéíóúÁÉÍÓÚñÑ';
    const sinTilde = 'aeiouAEIOUnN';
    var texto = input.toLowerCase();
    for (var i = 0; i < conTilde.length; i++) {
      texto = texto.replaceAll(conTilde[i], sinTilde[i].toLowerCase());
    }
    texto = texto.replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
    return texto.replaceAll(RegExp(r'\s+'), '-');
  }
}
