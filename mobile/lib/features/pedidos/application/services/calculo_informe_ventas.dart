import '../../domain/models/contadores_dia.dart';
import '../../domain/models/informe_ventas.dart';
import '../../domain/models/resumen_ventas_dia.dart';

// ═════════════════════════════════════════════════════════════════════════
// CalculoInformeVentas
// ═════════════════════════════════════════════════════════════════════════
// Junta los resúmenes diarios de un periodo en un informe. Función pura:
// suma enteros, no lee nada. Un día que no tiene documento simplemente no
// está en la lista (no vendió).
// ═════════════════════════════════════════════════════════════════════════
abstract final class CalculoInformeVentas {
  /// Cuántos puestos trae cada ranking.
  static const int maximoRanking = 10;

  static InformeVentas armar(
    String desde,
    String hasta,
    List<ResumenVentasDia> resumenes,
  ) {
    // Orden por día: así un empate siempre da el mismo resultado.
    final dias = [...resumenes]..sort((a, b) => a.dia.compareTo(b.dia));

    var ventas = 0;
    var entregados = 0;
    var mostradorCentavos = 0;
    var mostrador = 0;
    var anuladas = 0;
    var anuladasCentavos = 0;
    final porPago = <String, int>{};
    final porEntrega = <String, int>{};
    final porHora = <String, int>{};
    final productos = <String, ItemContador>{};
    final variantes = <String, ItemContador>{};
    final combos = <String, ItemContador>{};
    final conVentas = <DiaDeVentas>[];

    for (final r in dias) {
      ventas += r.ventasCentavos;
      entregados += r.entregados;
      final c = r.contadores;
      mostradorCentavos += c.mostradorCentavos;
      mostrador += c.mostrador;
      anuladas += c.anuladas;
      anuladasCentavos += c.anuladasCentavos;
      _sumarClaves(porPago, c.porPago);
      _sumarClaves(porEntrega, c.porEntrega);
      _sumarClaves(porHora, c.porHora);
      _sumarItems(productos, c.porProducto);
      _sumarItems(variantes, c.porVariante);
      _sumarItems(combos, c.porCombo);
      if (r.entregados > 0 || r.ventasCentavos > 0) {
        conVentas.add(
          DiaDeVentas(
            dia: r.dia,
            ventasCentavos: r.ventasCentavos,
            entregados: r.entregados,
          ),
        );
      }
    }

    DiaDeVentas? mejor;
    DiaDeVentas? flojo;
    for (final d in conVentas) {
      if (mejor == null || d.ventasCentavos > mejor.ventasCentavos) mejor = d;
      if (flojo == null || d.ventasCentavos < flojo.ventasCentavos) flojo = d;
    }
    // Con un solo día (o todos iguales) «el más flojo» no dice nada.
    if (mejor != null &&
        flojo != null &&
        mejor.ventasCentavos == flojo.ventasCentavos) {
      flojo = null;
    }

    return InformeVentas(
      desde: desde,
      hasta: hasta,
      ventasCentavos: ventas,
      entregados: entregados,
      diasConVentas: conVentas.length,
      mejorDia: mejor,
      diaMasFlojo: flojo,
      mostradorCentavos: mostradorCentavos,
      mostrador: mostrador,
      anuladas: anuladas,
      anuladasCentavos: anuladasCentavos,
      porPago: porPago,
      porEntrega: porEntrega,
      porHora: porHora,
      productos: _ranking(productos),
      variantes: _ranking(variantes),
      combos: _ranking(combos),
    );
  }

  static void _sumarClaves(Map<String, int> total, Map<String, int> dia) {
    for (final e in dia.entries) {
      total[e.key] = (total[e.key] ?? 0) + e.value;
    }
  }

  static void _sumarItems(
    Map<String, ItemContador> total,
    Map<String, ItemContador> dia,
  ) {
    for (final e in dia.entries) {
      final anterior = total[e.key];
      total[e.key] = anterior == null ? e.value : anterior.mas(e.value);
    }
  }

  /// Del que más vendió (en dinero) al que menos; si empatan, el de más
  /// cantidad y luego por nombre.
  static List<PuestoRanking> _ranking(Map<String, ItemContador> items) {
    final lista = [
      for (final e in items.entries)
        PuestoRanking(
          clave: e.key,
          nombre: e.value.nombre,
          cantidad: e.value.cantidad,
          centavos: e.value.centavos,
        ),
    ];
    lista.sort((a, b) {
      final porDinero = b.centavos.compareTo(a.centavos);
      if (porDinero != 0) return porDinero;
      final porCantidad = b.cantidad.compareTo(a.cantidad);
      if (porCantidad != 0) return porCantidad;
      return a.nombre.compareTo(b.nombre);
    });
    return lista.take(maximoRanking).toList();
  }
}
