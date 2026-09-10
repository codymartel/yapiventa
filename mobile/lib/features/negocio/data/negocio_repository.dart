import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/models/tipo_unidad.dart';
import '../domain/models/catalogo_negocio.dart';
import '../domain/models/zona_delivery.dart';
import '../domain/models/horario_dia.dart';
import '../domain/models/metodo_pago_tipo.dart';
import '../domain/models/config_pago_metodo.dart';
import '../domain/models/plantilla_web.dart';
import '../domain/models/seleccion_plantilla_info.dart';
import '../domain/repositories/repositorio_catalogo_negocio.dart';
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
// - Escribe en: users/{uid} — el MISMO documento que ya crea
//   user_repository.dart al registrarse. Este repository no crea el
//   documento, lo ACTUALIZA (update, no set) con los datos del negocio
//   — igual que hacía tu Kotlin.
// ═════════════════════════════════════════════════════════════════════════

class NegocioRepository
    implements RepositorioCatalogoNegocio, RepositorioSeleccionPlantilla {
  final FirebaseFirestore _firestore;

  NegocioRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<CatalogoNegocio> obtenerCatalogoNegocio(String uid) async {
    final documento = await _firestore.collection('users').doc(uid).get();
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
    final documento = await _firestore.collection('users').doc(uid).get();
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

  /// Guarda toda la configuración del negocio en users/{uid}.
  ///
  /// Recibe los datos ya validados y listos — este método solo arma el
  /// mapa y hace el update, igual que la segunda mitad de tu
  /// `ejecutarGuardado` (desde donde arma zonasMap/horariosMap/etc.
  /// hacia abajo).
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
      'setupComplete': true,
    };

    if (metodosActivos.isNotEmpty) {
      updateMap['metodosPago'] = metodosActivos;
      if (configPagosMap.isNotEmpty) updateMap['configPagos'] = configPagosMap;
    }

    await _firestore.collection('users').doc(uid).update(updateMap);
  }

  /// Guarda solo el id corto del molde web seleccionado.
  @override
  Future<void> guardarPlantillaWeb(String uid, PlantillaWeb plantilla) async {
    await _firestore.collection('users').doc(uid).update({
      'plantillaWeb': plantilla.valorPersistencia,
    });
  }
}
