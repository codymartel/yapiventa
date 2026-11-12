import '../../domain/models/opciones_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextosEntregaCaja
// ═════════════════════════════════════════════════════════════════════════
// Qué entregas ve cada rubro en Caja y cómo les dice. La entrega que se
// GUARDA no cambia (local, recojo o delivery): solo cambia la palabra.
//
//   Restaurante → En mesa · Para llevar · Delivery
//   Los demás   → En tienda · Delivery, y «En tienda» pregunta «¿Lo pidió
//                 antes para recoger?» (paso R: el Recojo como entrega queda
//                 solo para la tienda web)
//
// Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
abstract final class TextosEntregaCaja {
  /// Los chips de entrega de ese rubro, en orden.
  static List<EntregaCaja> entregas({required String rubro}) {
    return _esRestaurante(rubro)
        ? EntregaCaja.values
        : const [EntregaCaja.local, EntregaCaja.delivery];
  }

  /// Si se pregunta «¿Lo pidió antes para recoger?»: solo «En tienda», y no
  /// en restaurante (que ya tiene «Para llevar»).
  static bool preguntaPedidoPor(EntregaCaja entrega, {required String rubro}) {
    return entrega == EntregaCaja.local && !_esRestaurante(rubro);
  }

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
