import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/models/tipo_unidad.dart';
import '../domain/models/catalogo_negocio.dart';
import '../domain/models/zona_delivery.dart';
import '../domain/models/horario_dia.dart';
import '../domain/models/metodo_pago_tipo.dart';
import '../domain/models/config_pago_metodo.dart';
import '../domain/models/plantilla_web.dart';
import '../domain/models/progreso_configuracion.dart';
import '../domain/models/seleccion_plantilla_info.dart';
import '../domain/repositories/repositorio_catalogo_negocio.dart';
import '../domain/repositories/repositorio_progreso_configuracion.dart';
import '../domain/repositories/repositorio_seleccion_plantilla.dart';

// ═════════════════════════════════════════════════════════════════════════
// NegocioRepository
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Centraliza la lectura del catálogo y la escritura de la configuración del
// negocio en Firestore. La presentación nunca interpreta esos mapas.
//
// QUÉ NO HACE (a propósito, separado de este archivo):
// - NO valida nada (RUC, teléfono, links, montos) — eso vive en
//   configuracion_negocio_provider.dart, que valida ANTES de llamar a
//   este repository. Si algo inválido llega aquí, es porque el
//   provider falló en su trabajo, no algo que este archivo deba revisar.
// - NO genera el slug del negocio (generarSlug) — eso es una función
//   pura sin dependencia de Firestore, va en su propio archivo de
//   utilidades.
//
// CON QUÉ SE CONECTA:
// - Lo usan la configuración al guardar y ObtenerCatalogoNegocio al leer.
// - Lee negocioId en users/{uid} y opera sobre negocios/{negocioId}.
//   La única escritura al perfil es el vínculo negocioId, creado junto con
//   el negocio al guardar el primer rubro.
// - Al guardar la configuración o la plantilla, también proyecta los campos
//   públicos del negocio en negocios_publicos/{slug} para la tienda web.
// ═════════════════════════════════════════════════════════════════════════

class NegocioRepository
    implements
        RepositorioCatalogoNegocio,
        RepositorioSeleccionPlantilla,
        RepositorioProgresoConfiguracion {
  final FirebaseFirestore _firestore;

  NegocioRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Resuelve el id del negocio leyendo `users/{uid}.negocioId`.
  ///
  /// No escribe nada en users/{uid}: solo lo lee. Si el perfil no tiene
  /// negocioId (por ejemplo un usuario antiguo sin aprovisionar), lanza un
  /// error claro y la operación no se ejecuta sobre una ruta incorrecta.
  Future<String?> _obtenerNegocioIdOpcional(String uid) async {
    final perfil = await _firestore.collection('users').doc(uid).get();
    final negocioId = perfil.data()?['negocioId'];
    return negocioId is String && negocioId.trim().isNotEmpty
        ? negocioId.trim()
        : null;
  }

  Future<String> _obtenerNegocioId(String uid) async {
    final negocioId = await _obtenerNegocioIdOpcional(uid);
    if (negocioId == null) {
      throw StateError(
        'No se encontró un negocioId para el usuario "$uid". '
        'Asegúrate de que el registro esté completo antes de operar el negocio.',
      );
    }
    return negocioId;
  }

  @override
  Future<CatalogoNegocio> obtenerCatalogoNegocio(String uid) async {
    final negocioId = await _obtenerNegocioId(uid);
    final documento = await _firestore
        .collection('negocios')
        .doc(negocioId)
        .get();
    final datos = documento.data() ?? const <String, dynamic>{};
    return CatalogoNegocio(
      rubro: datos['rubro'] as String? ?? '',
      categorias: _leerCategorias(datos['categorias']),
      unidadesMedida: _leerUnidades(datos['unidadesMedida']),
      configuracionInicial: datos,
    );
  }

  @override
  Future<SeleccionPlantillaInfo> obtenerSeleccionPlantilla(String uid) async {
    final negocioId = await _obtenerNegocioId(uid);
    final documento = await _firestore
        .collection('negocios')
        .doc(negocioId)
        .get();
    final datos = documento.data() ?? const <String, dynamic>{};
    final valorOficial = datos['plantillaWeb'];
    final campoOficialAusenteOVacio =
        valorOficial is! String || valorOficial.trim().isEmpty;
    final provieneDeCampoOficial = !campoOficialAusenteOVacio;
    final valorGuardado = provieneDeCampoOficial
        ? valorOficial
        : datos['plantilla'];

    return SeleccionPlantillaInfo(
      slug: (datos['slug'] as String?)?.trim() ?? '',
      plantillaGuardada: PlantillaWeb.desdePersistencia(valorGuardado),
      provieneDeCampoOficial: provieneDeCampoOficial,
    );
  }

  @override
  Future<ProgresoConfiguracion> obtenerProgresoConfiguracion(String uid) async {
    final negocioId = await _obtenerNegocioIdOpcional(uid);
    if (negocioId == null) {
      return ProgresoConfiguracion(
        catalogo: CatalogoNegocio(
          rubro: '',
          categorias: const [],
          unidadesMedida: const [],
        ),
        slug: '',
        plantilla: null,
        plantillaProvieneDeCampoOficial: false,
        rubroCompleto: false,
        negocioCompleto: false,
        productosCompletos: false,
        setupCompletePersistido: false,
        productosConfirmadosPersistidos: false,
      );
    }
    final negocioRef = _firestore.collection('negocios').doc(negocioId);
    final negocioDocumento = await negocioRef.get();
    final datos = negocioDocumento.data() ?? const <String, dynamic>{};
    final catalogo = CatalogoNegocio(
      rubro: datos['rubro'] is String ? datos['rubro'] as String : '',
      categorias: _leerCategorias(datos['categorias']),
      unidadesMedida: _leerUnidades(datos['unidadesMedida']),
      configuracionInicial: datos,
    );
    final rubroCompleto = _rubroValido(catalogo.rubro);
    final negocioCompleto =
        rubroCompleto &&
        _configuracionValida(datos, catalogo) &&
        datos['onboardingBusinessNeedsReview'] != true;
    final productosConfirmados = datos['onboardingProductsConfirmed'] == true;
    var tieneProductoValido = productosConfirmados;
    if (negocioCompleto && !productosConfirmados) {
      // Los productos viven en negocios/{negocioId}/productos.
      final productos = await negocioRef
          .collection('productos')
          .orderBy('fechaCreacion', descending: true)
          .get();
      tieneProductoValido = productos.docs.any(
        (documento) => _productoValido(documento.data()),
      );
    }

    final valorOficial = datos['plantillaWeb'];
    final plantillaProvieneDeCampoOficial =
        valorOficial is String && valorOficial.trim().isNotEmpty;
    final plantilla = PlantillaWeb.desdePersistencia(
      plantillaProvieneDeCampoOficial ? valorOficial : datos['plantilla'],
    );

    return ProgresoConfiguracion(
      catalogo: catalogo,
      slug: datos['slug'] is String ? (datos['slug'] as String).trim() : '',
      plantilla: plantilla,
      plantillaProvieneDeCampoOficial: plantillaProvieneDeCampoOficial,
      rubroCompleto: rubroCompleto,
      negocioCompleto: negocioCompleto,
      productosCompletos: negocioCompleto && tieneProductoValido,
      setupCompletePersistido: datos['setupComplete'] == true,
      productosConfirmadosPersistidos: productosConfirmados,
    );
  }

  @override
  Future<void> guardarRubro(String uid, String rubro) async {
    final rubroLimpio = rubro.trim();
    if (!_rubroValido(rubroLimpio)) {
      throw ArgumentError.value(rubro, 'rubro', 'El rubro no es válido.');
    }

    final perfilRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final perfil = await transaction.get(perfilRef);
      if (!perfil.exists) {
        throw StateError('No se encontró el perfil del usuario "$uid".');
      }

      final negocioIdActual = perfil.data()?['negocioId'];
      final tieneNegocio =
          negocioIdActual is String && negocioIdActual.trim().isNotEmpty;
      final referencia = tieneNegocio
          ? _firestore.collection('negocios').doc(negocioIdActual.trim())
          : _firestore.collection('negocios').doc();

      if (!tieneNegocio) {
        transaction.set(referencia, {
          'propietarioUid': uid,
          'rubro': rubroLimpio,
          'onboardingBusinessRubro': rubroLimpio,
          'onboardingRubroCompletedAt': FieldValue.serverTimestamp(),
          'setupComplete': false,
          'webActiva': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(perfilRef, {'negocioId': referencia.id});
        return;
      }

      final documento = await transaction.get(referencia);
      final datos = documento.data() ?? const <String, dynamic>{};
      final rubroAnterior = datos['rubro'] is String
          ? (datos['rubro'] as String).trim()
          : '';
      if (rubroAnterior == rubroLimpio &&
          datos['onboardingRubroCompletedAt'] != null) {
        return;
      }
      final cambioConConfiguracion =
          rubroAnterior.isNotEmpty &&
          rubroAnterior != rubroLimpio &&
          datos['nombreNegocio'] is String;
      final actualizacion = <String, dynamic>{
        'rubro': rubroLimpio,
        'onboardingRubroCompletedAt': FieldValue.serverTimestamp(),
      };
      if (cambioConConfiguracion) {
        actualizacion.addAll({
          'onboardingBusinessNeedsReview': true,
          'setupComplete': false,
        });
      }
      transaction.set(referencia, actualizacion, SetOptions(merge: true));
    });
  }

  @override
  Future<void> sincronizarProgresoReconstruido(
    String uid, {
    required bool setupComplete,
    required bool confirmarProductos,
  }) async {
    final negocioId = await _obtenerNegocioId(uid);
    final actualizacion = <String, dynamic>{'setupComplete': setupComplete};
    if (confirmarProductos) {
      actualizacion.addAll({
        'onboardingProductsConfirmed': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      });
    }
    await _firestore
        .collection('negocios')
        .doc(negocioId)
        .set(actualizacion, SetOptions(merge: true));
  }

  bool _rubroValido(String rubro) => const {
    'Bodega',
    'Restaurante',
    'Ropa',
    'Farmacia',
    'Ferretería',
    'Otros',
  }.contains(rubro.trim());

  bool _configuracionValida(
    Map<String, dynamic> datos,
    CatalogoNegocio catalogo,
  ) {
    final nombre = datos['nombreNegocio'];
    final telefono = datos['telefono'];
    final direccion = datos['direccion'];
    final rubroConfigurado = datos['onboardingBusinessRubro'];
    final correspondeAlRubro =
        rubroConfigurado is! String ||
        rubroConfigurado.trim().isEmpty ||
        rubroConfigurado.trim() == catalogo.rubro.trim();
    final deliveryValido =
        datos['delivery'] != true ||
        (datos['deliveryZonas'] is List &&
            (datos['deliveryZonas'] as List).isNotEmpty);
    return nombre is String &&
        nombre.trim().length >= 3 &&
        telefono is String &&
        telefono.trim().isNotEmpty &&
        direccion is String &&
        direccion.trim().length >= 5 &&
        catalogo.categorias.isNotEmpty &&
        catalogo.unidadesMedida.isNotEmpty &&
        correspondeAlRubro &&
        deliveryValido;
  }

  bool _productoValido(Map<String, dynamic> datos) {
    final nombre = datos['nombre'];
    final precio = datos['precio'];
    final stock = datos['stock'];
    final categoria = datos['categoria'];
    final unidad = datos['unidadMedidaNombre'];
    final negocioId = datos['negocioId'];
    final fechaCreacion = datos['fechaCreacion'];
    return nombre is String &&
        nombre.trim().isNotEmpty &&
        negocioId is String &&
        negocioId.trim().isNotEmpty &&
        fechaCreacion is Timestamp &&
        precio is num &&
        precio > 0 &&
        stock is num &&
        stock >= 0 &&
        categoria is String &&
        categoria.trim().isNotEmpty &&
        unidad is String &&
        unidad.trim().isNotEmpty;
  }

  Future<bool> existenProductosDependientes({
    required String uid,
    required List<String> categorias,
    required List<String> unidades,
  }) async {
    final negocioId = await _obtenerNegocioId(uid);
    final productos = _firestore
        .collection('negocios')
        .doc(negocioId)
        .collection('productos');
    for (final categoria in categorias) {
      final resultado = await productos
          .where('categoria', isEqualTo: categoria)
          .limit(1)
          .get();
      if (resultado.docs.isNotEmpty) return true;
    }
    for (final unidad in unidades) {
      final resultado = await productos
          .where('unidadMedidaNombre', isEqualTo: unidad)
          .limit(1)
          .get();
      if (resultado.docs.isNotEmpty) return true;
    }
    return false;
  }

  List<String> _leerCategorias(Object? valor) {
    if (valor is! List) return const [];

    final categorias = <String>[];
    final nombres = <String>{};
    for (final elemento in valor) {
      if (elemento is! String) continue;
      final nombre = elemento.trim();
      if (nombre.isNotEmpty && nombres.add(nombre)) categorias.add(nombre);
    }
    return categorias;
  }

  List<UnidadInfo> _leerUnidades(Object? valor) {
    if (valor is! List) return const [];

    final unidades = <UnidadInfo>[];
    final nombres = <String>{};
    for (final elemento in valor) {
      if (elemento is! Map) continue;
      final datos = Map<String, dynamic>.from(elemento);
      final nombre = (datos['nombre'] as String?)?.trim() ?? '';
      final tipo = switch (datos['tipo']) {
        'entera' => TipoUnidad.entera,
        'fraccionaria' => TipoUnidad.fraccionaria,
        _ => null,
      };
      if (nombre.isEmpty || tipo == null || !nombres.add(nombre)) continue;

      final fracciones = <String>[];
      final valores = <String>{};
      final fraccionesGuardadas = datos['fraccionesPermitidas'];
      if (fraccionesGuardadas is List) {
        for (final elemento in fraccionesGuardadas) {
          if (elemento is! String) continue;
          final fraccion = elemento.trim();
          if (fraccion.isNotEmpty && valores.add(fraccion)) {
            fracciones.add(fraccion);
          }
        }
      }

      unidades.add(
        UnidadInfo(
          nombre: nombre,
          tipo: tipo,
          fraccionesPermitidas: fracciones,
          esOpcional: datos['esOpcional'] as bool? ?? false,
        ),
      );
    }
    return unidades;
  }

  /// Guarda toda la configuración del negocio en negocios/{negocioId}.
  ///
  /// Recibe los datos ya validados y listos — este método solo arma el
  /// mapa y hace el set con merge, igual que la segunda mitad de tu
  /// `ejecutarGuardado` (desde donde arma zonasMap/horariosMap/etc.
  /// hacia abajo). users/{uid} solo se lee para resolver negocioId.
  Future<void> guardarConfiguracionNegocio({
    required String uid,
    required String rubro,
    required String nombreNegocio,
    required String slug,
    required String telefonoCompleto, // ya con prefijo de país incluido
    required String direccionCompleta, // dirección + referencia combinadas
    required String ruc,
    required String facebook,
    required String tiktok,
    required String instagram,
    required String youtube,
    required List<String> categorias,
    required List<UnidadInfo> unidadesMedida,
    required bool tieneDelivery,
    required List<ZonaDelivery> zonasDelivery,
    required List<HorarioDia> horarios,
    required List<ConfigPagoMetodo> metodosPagoConfig,
  }) async {
    final zonasMap = zonasDelivery
        .map((z) => {'zona': z.zona, 'costo': double.tryParse(z.costo) ?? 0.0})
        .toList();

    final horariosMap = horarios
        .map(
          (h) => {
            'dia': h.dia,
            'apertura': h.apertura,
            'cierre': h.cierre,
            'activo': h.activo,
          },
        )
        .toList();

    final metodosActivos = metodosPagoConfig
        .where((c) => c.activo)
        .map((c) => c.metodoId)
        .toList();

    final configPagosMap = <String, dynamic>{};
    for (final config in metodosPagoConfig.where((c) => c.activo)) {
      final tipo = MetodoPagoTipo.porId(config.metodoId);
      final metodoMap = <String, dynamic>{};

      if (tipo?.permiteNumeroPersonalizado == true &&
          config.numeroPago.isNotEmpty) {
        metodoMap['numero'] = config.numeroPago;
      }
      if (tipo?.permiteDescuento == true) {
        metodoMap['descuentoActivo'] = config.descuentoActivo;
        metodoMap['montoMinimo'] = double.tryParse(config.montoMinimo) ?? 0.0;
        if (config.descuentoActivo) {
          metodoMap['tipoDescuento'] =
              config.tipoDescuento == TipoDescuento.porcentaje
              ? 'porcentaje'
              : 'monto_fijo';
          metodoMap['valorDescuento'] =
              double.tryParse(config.valorDescuento) ?? 0.0;
        }
      }
      if (metodoMap.isNotEmpty) configPagosMap[config.metodoId] = metodoMap;
    }

    final unidadesMap = unidadesMedida
        .map(
          (u) => {
            'nombre': u.nombre,
            'tipo': u.tipo == TipoUnidad.entera ? 'entera' : 'fraccionaria',
            'fraccionesPermitidas': u.fraccionesPermitidas,
            'esOpcional': u.esOpcional,
          },
        )
        .toList();

    final updateMap = <String, dynamic>{
      'rubro': rubro,
      'nombreNegocio': nombreNegocio.trim(),
      'slug': slug,
      'telefono': telefonoCompleto,
      'direccion': direccionCompleta,
      'ruc': ruc,
      'facebook': facebook,
      'tiktok': tiktok,
      'instagram': instagram,
      'youtube': youtube,
      'categorias': categorias,
      'unidadesMedida': unidadesMap,
      'delivery': tieneDelivery,
      'deliveryZonas': zonasMap,
      'horarios': horariosMap,
      'metodosPago': metodosActivos,
      'configPagos': configPagosMap,
      'onboardingBusinessRubro': rubro,
      'onboardingBusinessNeedsReview': false,
      'onboardingBusinessCompletedAt': FieldValue.serverTimestamp(),
    };

    final negocioId = await _obtenerNegocioId(uid);
    final referencia = _firestore.collection('negocios').doc(negocioId);
    final anterior = await referencia.get();
    final slugAnterior = _leerSlug(anterior.data());
    await referencia.set(updateMap, SetOptions(merge: true));
    await _persistirProyeccionPublica(
      negocioId: negocioId,
      slugAnterior: slugAnterior,
    );
  }

  /// Guarda solo el id corto del molde web seleccionado.
  @override
  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla) async {
    final progreso = await obtenerProgresoConfiguracion(uid);
    if (!progreso.productosCompletos || progreso.slug.trim().isEmpty) {
      throw StateError(
        'Completa el negocio y agrega al menos un producto válido antes de elegir la plantilla.',
      );
    }
    final negocioId = await _obtenerNegocioId(uid);
    await _firestore.collection('negocios').doc(negocioId).set({
      'plantillaWeb': plantilla.valorPersistencia,
      'onboardingTemplateCompletedAt': FieldValue.serverTimestamp(),
      'onboardingProductsConfirmed': true,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'setupComplete': true,
    }, SetOptions(merge: true));
    await _persistirProyeccionPublica(
      negocioId: negocioId,
      slugAnterior: progreso.slug,
    );
  }

  /// Lee el slug del documento del negocio, limpio, o '' si no hay.
  String _leerSlug(Map<String, dynamic>? datos) {
    final valor = datos?['slug'];
    return valor is String ? valor.trim() : '';
  }

  /// Proyecta los campos públicos del negocio en negocios_publicos/{slug}.
  ///
  /// Se llama tras guardar la configuración o la plantilla web. El doc
  /// público solo lleva datos que la tienda web necesita; nunca incluye
  /// email, terminosAceptados, ruc, setupComplete, datos del onboarding,
  /// plan ni propietarioUid. Si el slug cambió, elimina la ruta pública
  /// anterior para no dejar activo un enlace viejo.
  Future<void> _persistirProyeccionPublica({
    required String negocioId,
    required String slugAnterior,
  }) async {
    final referencia = _firestore.collection('negocios').doc(negocioId);
    final documento = await referencia.get();
    final datos = documento.data() ?? const <String, dynamic>{};
    final slug = _leerSlug(datos);

    if (slugAnterior.isNotEmpty && slugAnterior != slug) {
      await _firestore
          .collection('negocios_publicos')
          .doc(slugAnterior)
          .delete();
    }
    if (slug.isEmpty) return;

    await _firestore
        .collection('negocios_publicos')
        .doc(slug)
        .set(_construirProyeccionPublica(negocioId, datos));
  }

  Map<String, dynamic> _construirProyeccionPublica(
    String negocioId,
    Map<String, dynamic> datos,
  ) {
    final metodosPago = _leerMetodosPublicos(datos['metodosPago']);
    return <String, dynamic>{
      'negocioId': negocioId,
      'nombreNegocio': _texto(datos['nombreNegocio']),
      'slug': _leerSlug(datos),
      'rubro': _texto(datos['rubro']),
      'telefono': _texto(datos['telefono']),
      'direccion': _texto(datos['direccion']),
      'facebook': _texto(datos['facebook']),
      'instagram': _texto(datos['instagram']),
      'tiktok': _texto(datos['tiktok']),
      'youtube': _texto(datos['youtube']),
      'plantillaWeb': _texto(datos['plantillaWeb']),
      'webActiva': datos['webActiva'] == true,
      'categorias': _leerCategorias(datos['categorias']),
      'delivery': datos['delivery'] == true,
      'deliveryZonas': _leerZonasPublicas(datos['deliveryZonas']),
      'horarios': _leerHorariosPublicos(datos['horarios']),
      'metodosPago': metodosPago,
      'configPagos': _leerConfigPagosPublicos(
        datos['configPagos'],
        metodosPago,
      ),
    };
  }

  String _texto(Object? valor) => valor is String ? valor.trim() : '';

  List<String> _leerMetodosPublicos(Object? valor) {
    if (valor is! List) return const [];

    final metodos = <String>[];
    final vistos = <String>{};
    for (final elemento in valor) {
      if (elemento is! String) continue;
      final metodo = elemento.trim();
      if (metodo.isNotEmpty && vistos.add(metodo)) metodos.add(metodo);
    }
    return metodos;
  }

  List<Map<String, dynamic>> _leerZonasPublicas(Object? valor) {
    if (valor is! List) return const [];

    final zonas = <Map<String, dynamic>>[];
    for (final elemento in valor) {
      if (elemento is! Map) continue;
      final datosZona = Map<String, dynamic>.from(elemento);
      final zona = _texto(datosZona['zona']);
      if (zona.isEmpty) continue;
      zonas.add({'zona': zona, 'costo': _numeroNoNegativo(datosZona['costo'])});
    }
    return zonas;
  }

  List<Map<String, dynamic>> _leerHorariosPublicos(Object? valor) {
    if (valor is! List) return const [];

    final horarios = <Map<String, dynamic>>[];
    for (final elemento in valor) {
      if (elemento is! Map) continue;
      final datosHorario = Map<String, dynamic>.from(elemento);
      final dia = _texto(datosHorario['dia']);
      if (dia.isEmpty) continue;
      horarios.add({
        'dia': dia,
        'apertura': _texto(datosHorario['apertura']),
        'cierre': _texto(datosHorario['cierre']),
        'activo': datosHorario['activo'] == true,
      });
    }
    return horarios;
  }

  Map<String, dynamic> _leerConfigPagosPublicos(
    Object? valor,
    List<String> metodos,
  ) {
    if (valor is! Map) return const {};

    final configs = Map<String, dynamic>.from(valor);
    final publico = <String, dynamic>{};
    for (final metodo in metodos) {
      final config = configs[metodo];
      if (config is! Map) continue;
      publico[metodo] = Map<String, dynamic>.from(config);
    }
    return publico;
  }

  double _numeroNoNegativo(Object? valor) {
    final numero = valor is num ? valor.toDouble() : double.tryParse('$valor');
    return numero != null && numero.isFinite && numero >= 0 ? numero : 0;
  }
}
