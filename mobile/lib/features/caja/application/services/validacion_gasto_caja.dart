import 'package:mobile/features/pedidos/application/services/contadores_venta.dart';
import 'package:mobile/features/productos/application/services/entrada_numerica.dart';

// ═════════════════════════════════════════════════════════════════════════
// ValidacionGastoCaja
// ═════════════════════════════════════════════════════════════════════════
// Qué pide un gasto rápido, con los mismos límites que exigen las reglas de
// Firestore: monto mayor que cero y hasta S/ 100 000,00; de dónde salió la
// plata; nota opcional de hasta 120 letras. Función pura: devuelve el motivo
// en español simple, o null si está bien.
// ═════════════════════════════════════════════════════════════════════════
abstract final class ValidacionGastoCaja {
  static const int maximoCentavos = 10000000;
  static const int maxNota = 120;

  /// «10», «10,5» o «10.50» → céntimos. null si no es un monto válido.
  static int? montoDeTexto(String texto) => textoACentavos(texto);

  /// Al revés, para llenar el campo al corregir: 1000 → «10», 750 → «7,50».
  static String textoDeMonto(int centavos) {
    if (centavos <= 0) return '';
    final soles = centavos ~/ 100;
    final resto = centavos % 100;
    if (resto == 0) return '$soles';
    return '$soles,${resto.toString().padLeft(2, '0')}';
  }

  /// La clave de la forma de pago, igual a la que usan las ventas (así el
  /// efectivo gastado se resta del efectivo vendido).
  static String clavePago(String metodoPago) =>
      ContadoresVenta.clavePago(metodoPago);

  static String? revisar({
    required int? montoCentavos,
    required String metodoPago,
    String nota = '',
  }) {
    if (montoCentavos == null) return 'Escribe cuánto se gastó.';
    if (montoCentavos <= 0) return 'El monto debe ser mayor que cero.';
    if (montoCentavos > maximoCentavos) {
      return 'El monto es demasiado grande para un gasto de caja.';
    }
    if (metodoPago.trim().isEmpty) return 'Elige de dónde salió la plata.';
    if (nota.trim().length > maxNota) {
      return 'La nota es muy larga (máximo $maxNota letras).';
    }
    return null;
  }
}
