import 'package:mobile/features/pedidos/application/services/resumen_dia_pedidos.dart';

import '../../domain/models/gasto_caja.dart';
import '../../domain/models/opciones_caja.dart';
import 'validacion_gasto_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextosGastosCaja
// ═════════════════════════════════════════════════════════════════════════
// Lo que lee el cajero de cada gasto en «Gastos de hoy» y al corregirlo:
// «9:40 · Efectivo · almuerzo». Funciones puras, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
abstract final class TextosGastosCaja {
  /// «9:40» (hora de Lima). Un gasto recién guardado aún no tiene la hora
  /// del servidor: «ahora».
  static String hora(GastoCaja gasto) {
    final fecha = gasto.fecha;
    if (fecha == null) return 'ahora';
    final texto = ResumenDiaPedidos.horaLima(fecha);
    // «09:40» → «9:40»: más fácil de leer.
    return texto.startsWith('0') ? texto.substring(1) : texto;
  }

  /// El nombre de la forma de pago como la ve el negocio («Yape»). Si ya no
  /// está activa, la clave con mayúscula («Plin»).
  static String pago(GastoCaja gasto, List<OpcionPagoCaja> opciones) {
    for (final o in opciones) {
      if (ValidacionGastoCaja.clavePago(o.id) == gasto.metodoPago) {
        return o.etiqueta;
      }
    }
    final clave = gasto.metodoPago.replaceAll('_', ' ').trim();
    if (clave.isEmpty) return '';
    return clave[0].toUpperCase() + clave.substring(1);
  }

  /// La línea chica de un gasto: hora, de dónde salió y la nota.
  static String detalle(GastoCaja gasto, List<OpcionPagoCaja> opciones) {
    return [
      hora(gasto),
      pago(gasto, opciones),
      if (gasto.nota.trim().isNotEmpty) gasto.nota.trim(),
      if (gasto.anulado) 'anulado',
    ].where((t) => t.isNotEmpty).join(' · ');
  }

  /// Lo que se ve al corregir: «Antes: S/ 100,00 · Mercadería · 9:40».
  static String antes(GastoCaja gasto, String plata) =>
      'Antes: $plata · ${gasto.motivo.etiqueta} · ${hora(gasto)}';
}
