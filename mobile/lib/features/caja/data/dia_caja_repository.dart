import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/pedidos/data/resumen_ventas_dia_mapper.dart';

import '../domain/models/dia_caja.dart';
import '../domain/repositories/repositorios_gastos_caja.dart';
import 'gastos_caja_mapper.dart';

/// El día de Caja en vivo: escucha UN documento (el resumen del día) y saca
/// de él lo vendido y lo gastado.
///
/// Lecturas: 1 al empezar a escuchar y 1 cada vez que el resumen cambia (una
/// venta, una anulación o un gasto). Quien escucha cancela al salir.
class DiaCajaRepository implements RepositorioDiaCaja {
  DiaCajaRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<DiaCaja> escuchar(String negocioId, String dia) {
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No se encontró un negocioId para ver el día.');
    }
    return _db
        .collection('negocios')
        .doc(id)
        .collection('resumenes')
        .doc(dia)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          return DiaCaja(
            ventas: ResumenVentasDiaMapper.desdeFirestore(dia, data),
            gastos: GastosCajaMapper.gastosDiaDesdeFirestore(data),
          );
        });
  }
}
