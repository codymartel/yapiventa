import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/productos/data/mappers/lectura_firestore.dart';

import '../domain/models/dia_caja.dart';
import '../domain/models/gasto_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// GastosCajaMapper
// ═════════════════════════════════════════════════════════════════════════
// Documento de Firestore ↔ [GastoCaja], y los campos de gastos del resumen
// del día ↔ [GastosDia]. En el resumen van como campos sueltos:
//
//   gastosCentavos, gastos        → enteros
//   porGastoPago, porGastoMotivo  → {clave: céntimos}
//
// Lectura defensiva: un campo ausente, raro o negativo cuenta como 0.
//
// Los escribe `GastosCajaRepository`, solo esos campos: los de ventas (que
// escribe Pedidos) no se tocan.
// ═════════════════════════════════════════════════════════════════════════
abstract final class GastosCajaMapper {
  /// Cuántas claves se leen de cada mapa como máximo.
  static const int maximoClaves = 20;

  static GastoCaja gastoDesdeFirestore(String id, Map<String, dynamic> data) {
    final fecha = data['fecha'];
    final monto = LecturaFirestore.entero(data['montoCentavos']);
    return GastoCaja(
      id: id,
      montoCentavos: monto < 0 ? 0 : monto,
      motivo: MotivoGasto.desdeId(LecturaFirestore.texto(data['motivo'])),
      metodoPago: LecturaFirestore.texto(data['metodoPago']),
      dia: LecturaFirestore.texto(data['dia']),
      nota: LecturaFirestore.texto(data['nota']),
      fecha: fecha is Timestamp ? fecha.toDate() : null,
      anulado: data['anulado'] == true,
    );
  }

  /// Los campos de un gasto NUEVO (la fecha la pone el servidor).
  static Map<String, dynamic> gastoNuevoAMapa(GastoCaja gasto) {
    return {
      'montoCentavos': gasto.montoCentavos,
      'motivo': gasto.motivo.id,
      'metodoPago': gasto.metodoPago,
      'dia': gasto.dia,
      if (gasto.nota.isNotEmpty) 'nota': gasto.nota,
      'fecha': FieldValue.serverTimestamp(),
      'anulado': false,
    };
  }

  static GastosDia gastosDiaDesdeFirestore(Map<String, dynamic>? data) {
    if (data == null) return GastosDia.vacio;
    return GastosDia(
      totalCentavos: _noNegativo(data['gastosCentavos']),
      cantidad: _noNegativo(data['gastos']),
      porPago: _enteros(data['porGastoPago']),
      porMotivo: _enteros(data['porGastoMotivo']),
    );
  }

  static Map<String, int> _enteros(Object? valor) {
    if (valor is! Map) return const {};
    final salida = <String, int>{};
    for (final e in valor.entries) {
      if (salida.length >= maximoClaves) break;
      final n = _noNegativo(e.value);
      if (n > 0) salida['${e.key}'] = n;
    }
    return salida;
  }

  static int _noNegativo(Object? valor) {
    final entero = LecturaFirestore.entero(valor);
    return entero < 0 ? 0 : entero;
  }
}
