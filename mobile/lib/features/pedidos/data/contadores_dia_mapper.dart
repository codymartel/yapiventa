import 'package:mobile/features/productos/data/mappers/lectura_firestore.dart';

import '../application/services/contadores_venta.dart';
import '../domain/models/contadores_dia.dart';

// ═════════════════════════════════════════════════════════════════════════
// ContadoresDiaMapper
// ═════════════════════════════════════════════════════════════════════════
// Los contadores del día ↔ los campos del documento del resumen
// (negocios/{id}/resumenes/AAAA-MM-DD). Van como campos sueltos del mismo
// documento:
//
//   mostradorCentavos, mostrador, anuladas, anuladasCentavos  → enteros
//   porCobrarCentavos, porCobrar                              → enteros
//   porPago, porEntrega, porHora                              → {clave: céntimos}
//   porProducto, porVariante, porCombo → {clave: {nombre, cantidad, centavos}}
//
// Lectura defensiva: un campo ausente, de otro tipo o negativo cuenta como 0 o
// vacío; el resumen nunca rompe la pantalla. Un resumen viejo (sin contadores)
// se lee como un día sin movimientos.
//
// IMPORTANTE al escribir: usar `SetOptions(mergeFields: camposContadores)`. Un
// `merge: true` normal junta los mapas con lo que ya había y no quita las
// entradas que llegaron a 0 al anular.
// ═════════════════════════════════════════════════════════════════════════
abstract final class ContadoresDiaMapper {
  /// Los campos del resumen que pertenecen a los contadores.
  static const List<String> camposContadores = [
    'mostradorCentavos',
    'mostrador',
    'anuladas',
    'anuladasCentavos',
    'porPago',
    'porEntrega',
    'porHora',
    'porProducto',
    'porVariante',
    'porCombo',
    'porCobrarCentavos',
    'porCobrar',
  ];

  /// Cuántas entradas se leen de cada lista como máximo (el tope del día más
  /// la de «Otros»): un documento raro no llena la pantalla.
  static const int maximoLeidas = ContadoresVenta.maximoPorLista + 1;

  static ContadoresDia desdeFirestore(Map<String, dynamic> data) {
    return ContadoresDia(
      mostradorCentavos: _noNegativo(data['mostradorCentavos']),
      mostrador: _noNegativo(data['mostrador']),
      anuladas: _noNegativo(data['anuladas']),
      anuladasCentavos: _noNegativo(data['anuladasCentavos']),
      porPago: _enteros(data['porPago']),
      porEntrega: _enteros(data['porEntrega']),
      porHora: _enteros(data['porHora']),
      porProducto: _items(data['porProducto']),
      porVariante: _items(data['porVariante']),
      porCombo: _items(data['porCombo']),
      porCobrarCentavos: _noNegativo(data['porCobrarCentavos']),
      porCobrar: _noNegativo(data['porCobrar']),
    );
  }

  static Map<String, dynamic> aCampos(ContadoresDia c) {
    return {
      'mostradorCentavos': c.mostradorCentavos,
      'mostrador': c.mostrador,
      'anuladas': c.anuladas,
      'anuladasCentavos': c.anuladasCentavos,
      'porPago': c.porPago,
      'porEntrega': c.porEntrega,
      'porHora': c.porHora,
      'porProducto': _itemsAMapa(c.porProducto),
      'porVariante': _itemsAMapa(c.porVariante),
      'porCombo': _itemsAMapa(c.porCombo),
      'porCobrarCentavos': c.porCobrarCentavos,
      'porCobrar': c.porCobrar,
    };
  }

  // ── Partes ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _itemsAMapa(Map<String, ItemContador> items) {
    return {
      for (final e in items.entries)
        e.key: {
          'nombre': e.value.nombre,
          'cantidad': e.value.cantidad,
          'centavos': e.value.centavos,
        },
    };
  }

  static Map<String, int> _enteros(Object? valor) {
    if (valor is! Map) return const {};
    final resultado = <String, int>{};
    for (final e in valor.entries) {
      if (resultado.length >= maximoLeidas) break;
      if (e.key is! String) continue;
      final numero = _noNegativo(e.value);
      if (numero > 0) resultado[e.key as String] = numero;
    }
    return resultado;
  }

  static Map<String, ItemContador> _items(Object? valor) {
    if (valor is! Map) return const {};
    final resultado = <String, ItemContador>{};
    for (final e in valor.entries) {
      if (resultado.length >= maximoLeidas) break;
      if (e.key is! String || e.value is! Map) continue;
      final m = e.value as Map;
      final item = ItemContador(
        nombre: LecturaFirestore.texto(m['nombre']),
        cantidad: _noNegativo(m['cantidad']),
        centavos: _noNegativo(m['centavos']),
      );
      if (!item.vacio) resultado[e.key as String] = item;
    }
    return resultado;
  }

  static int _noNegativo(Object? valor) {
    final entero = LecturaFirestore.entero(valor);
    return entero < 0 ? 0 : entero;
  }
}
