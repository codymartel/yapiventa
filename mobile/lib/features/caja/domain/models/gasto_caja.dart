// ═════════════════════════════════════════════════════════════════════════
// MotivoGasto · GastoCaja
// ═════════════════════════════════════════════════════════════════════════
// Un gasto rápido de Caja: plata que SALE del negocio en el día («S/ 10 de
// comida», «pasaje», «bolsas»). Vive en negocios/{id}/gastos/{id} y suma al
// resumen de su día. Se anula, nunca se borra. El monto va en céntimos
// enteros.
//
// Los motivos son una lista CERRADA (así los informes pueden sumarlos); el
// detalle libre va en la nota.
// ═════════════════════════════════════════════════════════════════════════
enum MotivoGasto {
  comida('comida', 'Comida'),
  pasaje('pasaje', 'Pasaje'),
  mercaderia('mercaderia', 'Mercadería'),
  servicios('servicios', 'Servicios'),
  otro('otro', 'Otro');

  const MotivoGasto(this.id, this.etiqueta);

  /// Lo que se guarda.
  final String id;

  /// Lo que lee el cajero.
  final String etiqueta;

  /// Un valor desconocido (de una versión futura) se lee como «Otro».
  static MotivoGasto desdeId(String id) {
    for (final m in values) {
      if (m.id == id) return m;
    }
    return otro;
  }
}

class GastoCaja {
  const GastoCaja({
    required this.id,
    required this.montoCentavos,
    required this.motivo,
    required this.metodoPago,
    required this.dia,
    this.nota = '',
    this.fecha,
    this.anulado = false,
  });

  final String id;
  final int montoCentavos;
  final MotivoGasto motivo;

  /// De dónde salió la plata («efectivo», «yape»…), con la misma clave que
  /// usan las ventas: así «efectivo en caja» resta lo justo.
  final String metodoPago;

  /// AAAA-MM-DD (hora de Lima) del resumen al que suma. Se guarda para que
  /// anular reste del MISMO día.
  final String dia;
  final String nota;
  final DateTime? fecha;
  final bool anulado;
}
