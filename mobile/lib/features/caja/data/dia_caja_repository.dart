import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';

import '../domain/models/dia_caja.dart';
import '../domain/models/gasto_caja.dart';
import '../domain/repositories/repositorios_gastos_caja.dart';
import 'gastos_caja_mapper.dart';

/// Lee el día de Caja:
///
///   - en vivo: escucha UN documento (el resumen del día) y saca de él lo
///     vendido y lo gastado. 1 lectura al empezar y 1 cada vez que el resumen
///     cambia. Quien escucha cancela al salir.
///   - los gastos del día, una sola vez, para verlos y corregirlos: 1 lectura
///     por gasto, con tope. Solo filtra por `dia` (igualdad en un campo): no
///     pide índice nuevo; el orden se pone en memoria.
class DiaCajaRepository implements RepositorioDiaCaja, RepositorioGastosDelDia {
  DiaCajaRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _negocio(String negocioId) {
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No se encontró un negocioId para ver el día.');
    }
    return _db.collection('negocios').doc(id);
  }

  @override
  Future<List<GastoCaja>> delDia(
    String negocioId,
    String dia, {
    int limite = 20,
  }) async {
    final snap = await _negocio(negocioId)
        .collection('gastos')
        .where('dia', isEqualTo: dia)
        .limit(limite < 1 ? 1 : limite)
        .get();
    return [
      for (final doc in snap.docs)
        GastosCajaMapper.gastoDesdeFirestore(doc.id, doc.data()),
    ];
  }

  @override
  Stream<DiaCaja> escuchar(String negocioId, String dia) {
    return _negocio(negocioId).collection('resumenes').doc(dia).snapshots().map(
      (doc) {
        final data = doc.data();
        return DiaCaja(
          ventas: ResumenVentasDiaMapper.desdeFirestore(dia, data),
          gastos: GastosCajaMapper.gastosDiaDesdeFirestore(data),
        );
      },
    );
  }
}
