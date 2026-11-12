// ═════════════════════════════════════════════════════════════════════════
// FormaCaja · TamanosCaja
// ═════════════════════════════════════════════════════════════════════════
// Cómo se acomoda Caja según el espacio que tiene, con los mismos cortes que
// Pedidos. Son dos familias:
//
//   Familia 1 (mismo diseño base)   celular   menos de 600 px
//                                   tableta   600 a 1 099 px (ticket al lado)
//   Familia 2 (tablero)             pc        1 100 a 1 599 px
//                                   tv        1 600 px o más (solo se mira)
//
// «Poco alto» es un celular de lado o una ventana bajita: ahí nada se apila
// ni se aplasta; se pasa a columnas o a una fila compacta.
//
// Función pura, sin Flutter: recibe números.
// ═════════════════════════════════════════════════════════════════════════
enum FormaCaja {
  celular,
  tableta,
  pc,
  tv;

  /// Celular y tableta: hojas desde abajo y el mismo diseño.
  bool get esFamiliaMovil => this == celular || this == tableta;

  /// Tableta y PC: el ticket vive en un panel al costado.
  bool get ticketAlLado => this == tableta || this == pc;
}

abstract final class TamanosCaja {
  static const double anchoTableta = 600;
  static const double anchoPc = 1100;
  static const double anchoTv = 1600;

  /// Menos de esto de alto es «poco alto» (celular de lado, ventana bajita).
  static const double altoBajo = 480;

  /// Con menos alto LIBRE que esto (por ejemplo, de lado y con el teclado
  /// abierto) una hoja muestra solo lo que se está escribiendo.
  static const double altoMinimoHoja = 260;

  static const double anchoTicketTableta = 300;
  static const double anchoTicketPc = 340;
  static const double anchoDialogo = 440;

  static FormaCaja forma(double ancho) {
    if (ancho >= anchoTv) return FormaCaja.tv;
    if (ancho >= anchoPc) return FormaCaja.pc;
    if (ancho >= anchoTableta) return FormaCaja.tableta;
    return FormaCaja.celular;
  }

  static bool esBajo(double alto) => alto < altoBajo;

  /// Columnas de la lista de productos.
  static int columnasLista(double anchoLista) {
    if (anchoLista >= 660) return 3;
    if (anchoLista >= 420) return 2;
    return 1;
  }
}
