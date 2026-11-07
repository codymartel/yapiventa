import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/resumen_ventas_dia.dart';
import '../domain/repositories/repositorio_resumenes_ventas.dart';
import 'ayudas_pedidos_firestore.dart';
import 'resumen_ventas_dia_mapper.dart';

/// Los resúmenes diarios de ventas (`negocios/{id}/resumenes/AAAA-MM-DD`) para
/// los informes: UNA consulta por rango de días (el id del documento es la
/// fecha), como máximo [maximoDiasInforme] documentos. No lee pedidos.
class ResumenesVentasRepository implements RepositorioResumenesVentas {
  ResumenesVentasRepository({FirebaseFirestore? db})
    : _ayudas = AyudasPedidosFirestore(
        db: db ?? FirebaseFirestore.instance,
        reloj: DateTime.now,
      );

  final AyudasPedidosFirestore _ayudas;

  /// Más de un mes por informe no hace falta (y cuesta lecturas).
  static const int maximoDiasInforme = 31;

  @override
  Future<List<ResumenVentasDia>> obtenerResumenes(
    String negocioId,
    String desde,
    String hasta,
  ) async {
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!formato.hasMatch(desde) ||
        !formato.hasMatch(hasta) ||
        desde.compareTo(hasta) > 0) {
      throw ArgumentError('El rango de días no es válido: $desde a $hasta.');
    }
    final dias =
        DateTime.parse(hasta).difference(DateTime.parse(desde)).inDays + 1;
    if (dias > maximoDiasInforme) {
      throw ArgumentError(
        'Un informe cubre como máximo $maximoDiasInforme días.',
      );
    }
    final resultado = await _ayudas
        .resumenes(negocioId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: desde)
        .where(FieldPath.documentId, isLessThanOrEqualTo: hasta)
        .limit(maximoDiasInforme)
        .get();
    return [
      for (final doc in resultado.docs)
        ResumenVentasDiaMapper.desdeFirestore(doc.id, doc.data()),
    ];
  }
}
