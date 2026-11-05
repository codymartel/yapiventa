import '../../domain/models/linea_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextoLineasPedido
// ═════════════════════════════════════════════════════════════════════════
// Cómo se ve lo pedido en la tarjeta y en el detalle. Texto plano.
//
// LÍMITE CONOCIDO: la línea guarda la cantidad en unidad base (350) pero no
// el nombre de la unidad (g, ml…): por ahora se muestra «350 Queso andino».
// Cuando la tienda escriba la unidad en el pedido se mostrará «350 g».
// ═════════════════════════════════════════════════════════════════════════
abstract final class TextoLineasPedido {
  /// «Queso andino» o «Polo básico (Luna · M)».
  static String nombre(LineaPedido linea) {
    return linea.etiqueta.isEmpty
        ? linea.nombre
        : '${linea.nombre} (${linea.etiqueta})';
  }

  /// «350» (por medida) o «×2» (se cuenta).
  static String cantidad(LineaPedido linea) {
    return linea.porMedida ? '${linea.cantidad}' : '×${linea.cantidad}';
  }

  /// «350 Queso andino» o «2× Inca 500 ml».
  static String linea(LineaPedido linea) {
    return linea.porMedida
        ? '${linea.cantidad} ${nombre(linea)}'
        : '${linea.cantidad}× ${nombre(linea)}';
  }

  /// Las primeras [max] líneas separadas por coma, y «y N más» si hay más.
  static String resumen(List<LineaPedido> lineas, {int max = 2}) {
    if (lineas.isEmpty) return 'Sin productos';
    final primeras = lineas.take(max).map(linea).join(', ');
    final resto = lineas.length - max;
    return resto > 0 ? '$primeras y $resto más' : primeras;
  }
}
