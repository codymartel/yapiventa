import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/dia_caja.dart';
import '../domain/models/gasto_caja.dart';
import '../domain/repositories/repositorios_gastos_caja.dart';
import 'gastos_caja_mapper.dart';

/// Gastos de Caja en Firestore: negocios/{id}/gastos/{gastoId}, y sus sumas
/// en el resumen del día (negocios/{id}/resumenes/AAAA-MM-DD).
///
/// Cada operación va en UNA transacción (todo o nada) y cuesta 2 lecturas (el
/// gasto y el resumen de su día) y 2 escrituras. Los gastos no se listan
/// aquí: el día se ve leyendo solo el resumen (`DiaCajaRepository`).
class GastosCajaRepository implements RepositorioGastosCaja {
  GastosCajaRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _negocio(String negocioId) {
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No se encontró un negocioId para operar los gastos.');
    }
    return _db.collection('negocios').doc(id);
  }

  @override
  Future<bool> registrar(String negocioId, GastoCaja gasto) {
    if (gasto.id.trim().isEmpty) {
      throw ArgumentError.value(gasto.id, 'id', 'El gasto no tiene id.');
    }
    if (gasto.montoCentavos <= 0) {
      throw ArgumentError.value(
        gasto.montoCentavos,
        'montoCentavos',
        'El monto debe ser mayor que cero.',
      );
    }
    final negocio = _negocio(negocioId);
    final ref = negocio.collection('gastos').doc(gasto.id.trim());
    final refResumen = negocio.collection('resumenes').doc(gasto.dia);

    return _db.runTransaction((tx) async {
      // Un toque repetido con el mismo id: ya está guardado, no suma otra vez.
      if ((await tx.get(ref)).exists) return false;
      final resumen = await tx.get(refResumen);
      final actual = GastosCajaMapper.gastosDiaDesdeFirestore(resumen.data());
      final nuevo = actual.mas(
        centavos: gasto.montoCentavos,
        pago: gasto.metodoPago,
        motivo: gasto.motivo.id,
      );
      tx.set(ref, GastosCajaMapper.gastoNuevoAMapa(gasto));
      _guardarResumen(tx, refResumen, actual, nuevo, existe: resumen.exists);
      return true;
    });
  }

  @override
  Future<ResultadoAnularGasto> anular(String negocioId, String gastoId) {
    if (gastoId.trim().isEmpty) {
      throw ArgumentError.value(gastoId, 'gastoId', 'El gasto no tiene id.');
    }
    final negocio = _negocio(negocioId);
    final ref = negocio.collection('gastos').doc(gastoId.trim());

    return _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data();
      if (!doc.exists || data == null) {
        return const ResultadoAnularGasto(yaAnulado: true);
      }
      final gasto = GastosCajaMapper.gastoDesdeFirestore(doc.id, data);
      // Un toque repetido (u otro cajero): no se resta dos veces.
      if (gasto.anulado) return const ResultadoAnularGasto(yaAnulado: true);

      // Se resta del día en que se guardó (no de hoy).
      final refResumen = negocio.collection('resumenes').doc(gasto.dia);
      final resumen = await tx.get(refResumen);
      final actual = GastosCajaMapper.gastosDiaDesdeFirestore(resumen.data());
      final nuevo = actual.menos(
        centavos: gasto.montoCentavos,
        pago: gasto.metodoPago,
        motivo: gasto.motivo.id,
      );
      tx.update(ref, {
        'anulado': true,
        'anuladoEn': FieldValue.serverTimestamp(),
      });
      _guardarResumen(tx, refResumen, actual, nuevo, existe: resumen.exists);
      return const ResultadoAnularGasto();
    });
  }

  /// Escribe SOLO los campos de gastos del resumen: los de ventas (que
  /// escribe Pedidos) no se tocan.
  ///
  /// Una clave que llegó a 0 (se anuló su único gasto) se escribe en 0 en vez
  /// de quitarse: así el resultado es el mismo si el mapa se reemplaza o se
  /// junta con el anterior. Al leer, los ceros se descartan. Son listas
  /// cortas (formas de pago y 5 motivos): no crecen.
  void _guardarResumen(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> refResumen,
    GastosDia antes,
    GastosDia ahora, {
    required bool existe,
  }) {
    final campos = {
      'gastosCentavos': ahora.totalCentavos,
      'gastos': ahora.cantidad,
      'porGastoPago': _conCeros(antes.porPago, ahora.porPago),
      'porGastoMotivo': _conCeros(antes.porMotivo, ahora.porMotivo),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    if (existe) {
      tx.update(refResumen, campos);
    } else {
      tx.set(refResumen, campos);
    }
  }

  static Map<String, int> _conCeros(
    Map<String, int> antes,
    Map<String, int> ahora,
  ) {
    return {for (final clave in antes.keys) clave: 0, ...ahora};
  }
}
