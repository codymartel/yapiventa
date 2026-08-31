import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/zona_delivery.dart';
import '../domain/models/horario_dia.dart';
import '../domain/models/metodo_pago_tipo.dart';
import '../domain/models/config_pago_metodo.dart';

// ═════════════════════════════════════════════════════════════════════════
// NegocioRepository
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Es el único lugar que escribe la configuración del negocio en
// Firestore. Equivale a la parte de tu `ejecutarGuardado` en Kotlin que
// arma el mapa y llama a `.update(...)` — SOLO esa parte.
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
// - Lo usa: configuracion_negocio_provider.dart, cuando el usuario
//   confirma "Finalizar" y ya pasó todas las validaciones.
// - Escribe en: users/{uid} — el MISMO documento que ya crea
//   user_repository.dart al registrarse. Este repository no crea el
//   documento, lo ACTUALIZA (update, no set) con los datos del negocio
//   — igual que hacía tu Kotlin.
// ═════════════════════════════════════════════════════════════════════════

class NegocioRepository {
  final FirebaseFirestore _firestore;

  NegocioRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Guarda toda la configuración del negocio en users/{uid}.
  ///
  /// Recibe los datos ya validados y listos — este método solo arma el
  /// mapa y hace el update, igual que la segunda mitad de tu
  /// `ejecutarGuardado` (desde donde arma zonasMap/horariosMap/etc.
  /// hacia abajo).
  Future<void> guardarConfiguracionNegocio({
    required String uid,
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
    required List<UnidadInfoResumen> unidadesMedida,
    required bool tieneDelivery,
    required List<ZonaDelivery> zonasDelivery,
    required List<HorarioDia> horarios,
    required List<ConfigPagoMetodo> metodosPagoConfig,
  }) async {
    final zonasMap = zonasDelivery
        .map((z) => {
              'zona': z.zona,
              'costo': double.tryParse(z.costo) ?? 0.0,
            })
        .toList();

    final horariosMap = horarios
        .map((h) => {
              'dia': h.dia,
              'apertura': h.apertura,
              'cierre': h.cierre,
              'activo': h.activo,
            })
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
          metodoMap['tipoDescuento'] = config.tipoDescuento == TipoDescuento.porcentaje
              ? 'porcentaje'
              : 'monto_fijo';
          metodoMap['valorDescuento'] =
              double.tryParse(config.valorDescuento) ?? 0.0;
        }
      }
      if (metodoMap.isNotEmpty) configPagosMap[config.metodoId] = metodoMap;
    }

    final unidadesMap = unidadesMedida
        .map((u) => {
              'nombre': u.nombre,
              'tipo': u.tipo,
              'fraccionesPermitidas': u.fraccionesPermitidas,
              'esOpcional': u.esOpcional,
            })
        .toList();

    final updateMap = <String, dynamic>{
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
}

/// Pequeño resumen de UnidadInfo solo con lo que se necesita guardar
/// (nombre, tipo como texto, fracciones, opcional) — evita que este
/// repository dependa del enum TipoUnidad completo, solo de su
/// representación como String para Firestore.
class UnidadInfoResumen {
  final String nombre;
  final String tipo; // 'entera' o 'fraccionaria'
  final List<String> fraccionesPermitidas;
  final bool esOpcional;

  const UnidadInfoResumen({
    required this.nombre,
    required this.tipo,
    required this.fraccionesPermitidas,
    required this.esOpcional,
  });
}