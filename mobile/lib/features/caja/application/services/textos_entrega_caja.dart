import '../../domain/models/opciones_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextosEntregaCaja
// ═════════════════════════════════════════════════════════════════════════
// Cómo le dice cada rubro a las tres entregas de Caja. La entrega que se
// GUARDA no cambia (local, recojo o delivery): solo cambia la palabra que lee
// el cajero. El rubro sugiere, no prohíbe: los seis rubros tienen las tres.
//
//   Restaurante → En mesa · Para llevar · Delivery
//   Los demás   → En tienda · Recojo · Delivery
//
// Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
abstract final class TextosEntregaCaja {
  /// La palabra del chip de entrega para ese rubro.
  static String etiqueta(EntregaCaja entrega, {required String rubro}) {
    final restaurante = _esRestaurante(rubro);
    return switch (entrega) {
      EntregaCaja.local => restaurante ? 'En mesa' : 'En tienda',
      EntregaCaja.recojo => restaurante ? 'Para llevar' : 'Recojo',
      EntregaCaja.delivery => 'Delivery',
    };
  }

  /// La ayuda del campo «cliente» cuando NO es delivery (es un alias
  /// opcional para ubicar la venta).
  static String ayudaCliente(EntregaCaja entrega, {required String rubro}) {
    if (entrega == EntregaCaja.delivery) return 'Nombre del cliente';
    if (_esRestaurante(rubro) && entrega == EntregaCaja.local) {
      return 'Mesa o nombre (opcional)';
    }
    return 'Nombre (opcional)';
  }

  static bool _esRestaurante(String rubro) =>
      rubro.trim().toLowerCase() == 'restaurante';
}
