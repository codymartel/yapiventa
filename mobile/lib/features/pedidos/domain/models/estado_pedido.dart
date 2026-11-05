// ═════════════════════════════════════════════════════════════════════════
// EstadoPedido · EstadoPago · EstadoReembolso
// ═════════════════════════════════════════════════════════════════════════
// Los 5 estados de un pedido (decidido el 2026-10-31): el stock baja al pasar
// de nuevo a confirmado y solo se puede cancelar hasta ahí. El tercer paso
// depende de la entrega: «listo» (recojo) o «en camino» (delivery).
//
//   nuevo → confirmado → listo | enCamino → entregado        (o cancelado)
//
// El reembolso NO es un estado: es una marca del pedido cancelado que ya
// estaba pagado ([EstadoReembolso]). Así el pedido nunca se borra.
// ═════════════════════════════════════════════════════════════════════════
enum EstadoPedido {
  nuevo('nuevo', 'Nuevo'),
  confirmado('confirmado', 'Confirmado'),
  enCamino('en_camino', 'En camino'),
  listo('listo', 'Listo para recoger'),
  entregado('entregado', 'Entregado'),
  cancelado('cancelado', 'Cancelado');

  const EstadoPedido(this.valor, this.etiqueta);

  /// Texto que se guarda en Firestore.
  final String valor;
  final String etiqueta;

  /// Sigue en marcha: aparece en la lista de abiertos.
  bool get abierto => this != entregado && this != cancelado;
  bool get esFinal => !abierto;

  /// Lee un valor guardado. Acepta los nombres de la app anterior (Kotlin) y
  /// cualquier valor desconocido lo trata como nuevo: nunca se pierde un pedido.
  static EstadoPedido desdeValor(String? valor) {
    return switch (valor) {
      'confirmado' || 'en_preparacion' => confirmado,
      'en_camino' => enCamino,
      'listo' || 'listo_para_recoger' => listo,
      'entregado' => entregado,
      'cancelado' || 'pendiente_reembolso' => cancelado,
      _ => nuevo,
    };
  }
}

enum EstadoPago {
  pendiente('pendiente'),
  pagado('pagado');

  const EstadoPago(this.valor);

  final String valor;

  static EstadoPago desdeValor(String? valor) {
    return switch (valor) {
      'pagado' || 'reembolsado' => pagado,
      _ => pendiente,
    };
  }
}

/// Solo tiene sentido en un pedido cancelado que ya estaba pagado.
enum EstadoReembolso {
  ninguno('ninguno'),
  pendiente('pendiente'),
  hecho('hecho');

  const EstadoReembolso(this.valor);

  final String valor;

  static EstadoReembolso desdeValor(String? valor) {
    return switch (valor) {
      'pendiente' => pendiente,
      'hecho' => hecho,
      _ => ninguno,
    };
  }
}
