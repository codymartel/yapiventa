import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/productos/data/mappers/lectura_firestore.dart';

import '../domain/models/resumen_ventas_dia.dart';
import 'contadores_dia_mapper.dart';

// ═════════════════════════════════════════════════════════════════════════
// ResumenVentasDiaMapper
// ═════════════════════════════════════════════════════════════════════════
// Documento de Firestore ↔ [ResumenVentasDia]. Lectura defensiva: un campo
// ausente o raro cuenta como 0 (el resumen nunca rompe la pantalla).
// ═════════════════════════════════════════════════════════════════════════
abstract final class ResumenVentasDiaMapper {
  static ResumenVentasDia desdeFirestore(
    String dia,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return ResumenVentasDia.vacio(dia);
    final lista = data['ultimosEntregados'];
    return ResumenVentasDia(
      dia: dia,
      ventasCentavos: _noNegativo(data['ventasCentavos']),
      entregados: _noNegativo(data['entregados']),
      confirmados: _noNegativo(data['confirmados']),
      sumaMinutosConfirmar: _noNegativo(data['sumaMinutosConfirmar']),
      ultimosEntregados: [
        if (lista is List)
          for (final item in lista)
            if (item is Map) _entregado(Map<String, dynamic>.from(item)),
      ],
      contadores: ContadoresDiaMapper.desdeFirestore(data),
    );
  }

  static List<Map<String, dynamic>> entregadosAMapas(
    List<EntregadoReciente> entregados,
  ) {
    return [
      for (final e in entregados)
        {
          'pedidoId': e.pedidoId,
          'clave': e.clave,
          'cliente': e.cliente,
          'productos': e.productos,
          'totalCentavos': e.totalCentavos,
          'metodoPago': e.metodoPago,
          'cobrado': e.cobrado,
          if (e.hora != null) 'hora': Timestamp.fromDate(e.hora!),
        },
    ];
  }

  static EntregadoReciente _entregado(Map<String, dynamic> m) {
    final hora = m['hora'];
    return EntregadoReciente(
      pedidoId: LecturaFirestore.texto(m['pedidoId']),
      clave: LecturaFirestore.texto(m['clave']),
      cliente: LecturaFirestore.texto(m['cliente']),
      productos: LecturaFirestore.texto(m['productos']),
      totalCentavos: _noNegativo(m['totalCentavos']),
      metodoPago: LecturaFirestore.texto(m['metodoPago']),
      cobrado: m['cobrado'] == true,
      hora: hora is Timestamp ? hora.toDate() : null,
    );
  }

  static int _noNegativo(Object? valor) {
    final entero = LecturaFirestore.entero(valor);
    return entero < 0 ? 0 : entero;
  }
}
