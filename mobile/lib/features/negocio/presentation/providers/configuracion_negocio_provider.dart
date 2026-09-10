import 'package:flutter/foundation.dart';
import '../../data/negocio_repository.dart';
import '../../domain/models/zona_delivery.dart';
import '../../domain/models/horario_dia.dart';
import '../../domain/models/metodo_pago_tipo.dart';
import '../../domain/models/config_pago_metodo.dart';
import '../../domain/models/pais_telefono.dart';
import '../../../../domain/models/categoria.dart';
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

  ConfiguracionNegocioProvider({
    required this.rubro,
    Map<String, dynamic>? configuracionInicial,
    NegocioRepository? repository,
  }) : _repository = repository ?? NegocioRepository() {
    // Igual que tu Kotlin: las categorías y unidades iniciales se cargan
    // según el rubro elegido en la pantalla anterior.
    _categorias = List.of(Categorias.obtener(rubro));
    _unidadesMedida = List.of(UnidadesMedida.obtener(rubro));
    if (configuracionInicial != null) {
      _restaurarConfiguracion(configuracionInicial);
    }
  }

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

  void agregarCategoria(String nombre) {
    _categorias.add(nombre);
    notifyListeners();
  }

  void editarCategoria(int index, String nuevoNombre) {
    _categorias[index] = nuevoNombre;
    notifyListeners();
  }

  void eliminarCategoria(int index) {
    _categorias.removeAt(index);
    notifyListeners();
  }

  late List<UnidadInfo> _unidadesMedida;
  List<UnidadInfo> get unidadesMedida => List.unmodifiable(_unidadesMedida);

  void agregarUnidad(UnidadInfo unidad) {
    _unidadesMedida.add(unidad);
    notifyListeners();
  }

  void editarUnidad(int index, UnidadInfo unidad) {
    _unidadesMedida[index] = unidad;
    notifyListeners();
  }

  void eliminarUnidad(int index) {
    _unidadesMedida.removeAt(index);
    notifyListeners();
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
  bool get faltaZonas => _tieneDelivery && _zonasDelivery.isEmpty;

  bool get puedeAvanzarPaso0 =>
      !faltaNombre &&
      !faltaTelefono &&
      !faltaDireccion &&
      !faltaReferencia &&
      !linksMalos;
  bool get puedeAvanzarPaso1 => !faltaCategoria;
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
      await _repository.guardarConfiguracionNegocio(
        uid: uid,
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
        tieneDelivery: _tieneDelivery,
        zonasDelivery: _zonasDelivery,
        horarios: _horarios,
        metodosPagoConfig: _metodosPagoConfig,
      );
      _guardando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _guardando = false;
      _errorValidacion = 'Error de conexión con Firebase.';
      notifyListeners();
      return false;
    }
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
