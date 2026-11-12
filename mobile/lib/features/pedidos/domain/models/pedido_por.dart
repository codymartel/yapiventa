// ═════════════════════════════════════════════════════════════════════════
// PedidoPor
// ═════════════════════════════════════════════════════════════════════════
// Por dónde avisó el cliente que pasaría a recoger una venta de Caja «En
// tienda» (paso R). Lista CERRADA: es lo único que se guarda y lo que acepta
// la regla de Firestore. «No lo pidió antes» no se guarda (el campo falta).
//
// Solo existe en ventas que no son delivery. Se cobra cuando el cliente llega
// y no aparta stock: es una venta en tienda más, con este dato.
// ═════════════════════════════════════════════════════════════════════════
enum PedidoPor {
  whatsapp('whatsapp', 'WhatsApp'),
  facebook('facebook', 'Facebook'),
  llamada('llamada', 'Llamada'),
  otro('otro', 'Otro');

  const PedidoPor(this.valor, this.etiqueta);

  /// Lo que se guarda en Firestore.
  final String valor;

  /// Lo que lee el vendedor.
  final String etiqueta;

  /// null si no trae nada o trae un valor desconocido (lectura defensiva).
  static PedidoPor? desdeValor(String? valor) {
    for (final p in values) {
      if (p.valor == valor) return p;
    }
    return null;
  }
}
