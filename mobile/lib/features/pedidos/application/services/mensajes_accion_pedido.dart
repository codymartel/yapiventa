import '../../domain/models/pedido.dart';
import '../../domain/repositories/repositorio_pedidos.dart';
import 'resumen_dia_pedidos.dart';
import 'resumen_ventas_dia_calculo.dart';
import '../use_cases/cancelar_vencidos.dart';

// ═════════════════════════════════════════════════════════════════════════
// MensajesAccionPedido
// ═════════════════════════════════════════════════════════════════════════
// Los textos que el vendedor lee después de confirmar, cancelar o cancelar
// vencidos. Funciones puras, sin Flutter. Los nombres vienen de los productos
// del negocio y se muestran como texto plano: nunca se interpretan.
// ═════════════════════════════════════════════════════════════════════════
abstract final class MensajesAccionPedido {
  /// 1840 → «18,40». Sin símbolo: la moneda depende del país del negocio
  /// (paso «País y moneda», pendiente). Con [simbolo] → «S/ 18,40».
  static String dinero(int centavos, {String simbolo = ''}) {
    final decimal = (centavos % 100).toString().padLeft(2, '0');
    final numero = '${centavos ~/ 100},$decimal';
    return simbolo.isEmpty ? numero : '$simbolo $numero';
  }

  /// Por qué NO se pudo confirmar (no se descontó nada).
  static String confirmarBloqueado(ResultadoConfirmar r) {
    if (r.yaNoEsNuevo) {
      return 'Este pedido ya no está nuevo: otro vendedor lo confirmó o lo '
          'canceló.';
    }
    final partes = <String>[];
    if (r.faltas.isNotEmpty) {
      final detalle = r.faltas
          .map((f) => '${f.nombre} (pide ${f.pide}, hay ${f.hay})')
          .join('; ');
      partes.add('No alcanza el stock: $detalle.');
    }
    if (r.sinProducto.isNotEmpty) {
      partes.add('Ya no existe: ${r.sinProducto.join(', ')}.');
    }
    return partes.join(' ');
  }

  /// Pedido confirmado; avisa si con los precios de hoy el total sería otro.
  static String confirmado(ResultadoConfirmar r, int totalGuardadoCentavos) {
    final actual = r.totalActualCentavos;
    if (actual == null) return 'Pedido confirmado.';
    final cambiadas = r.lineasCambiadas.isEmpty
        ? ''
        : ' (cambió: ${r.lineasCambiadas.join(', ')})';
    return 'Pedido confirmado. Con los precios de hoy el total sería '
        '${dinero(actual)}; el cliente vio ${dinero(totalGuardadoCentavos)}'
        '$cambiadas.';
  }

  /// Resultado de confirmar varios pedidos a la vez. [primerMotivo] es el
  /// porqué del primero que no se pudo confirmar (no se repite por cada uno).
  static String confirmadosEnLote(
    int confirmados,
    int bloqueados,
    String? primerMotivo,
  ) {
    final partes = <String>[];
    if (confirmados > 0) {
      partes.add(
        confirmados == 1
            ? 'Se confirmó 1 pedido.'
            : 'Se confirmaron $confirmados pedidos.',
      );
    }
    if (bloqueados > 0) {
      partes.add(
        bloqueados == 1
            ? '1 no se pudo confirmar.'
            : '$bloqueados no se pudieron confirmar.',
      );
      if (primerMotivo != null && primerMotivo.isNotEmpty) {
        partes.add(primerMotivo);
      }
    }
    return partes.isEmpty
        ? 'No había pedidos por confirmar.'
        : partes.join(' ');
  }

  static String cancelado(int lineasSinDevolver) {
    if (lineasSinDevolver == 0) return 'Pedido cancelado.';
    final lineas = lineasSinDevolver == 1
        ? 'un producto que ya no existe'
        : '$lineasSinDevolver productos que ya no existen';
    return 'Pedido cancelado. No se pudo devolver el stock de $lineas.';
  }

  /// Símbolo del MVP (solo Perú). Único lugar de este archivo.
  static const String _simbolo = 'S/';

  /// Texto de confirmación antes de anular una venta de Caja. Dice qué pasa
  /// con el stock y cuánto bajan las ventas, y de qué día.
  static String confirmarAnulacion(Pedido pedido, DateTime ahora) {
    final momento = ResumenVentasDiaCalculo.momentoDeEntrega(pedido) ?? ahora;
    final dia = ResumenDiaPedidos.claveDia(momento);
    final cuando = dia == ResumenDiaPedidos.claveDia(ahora)
        ? 'las ventas de hoy'
        : 'las ventas del ${ResumenDiaPedidos.etiquetaDia(dia)}';
    return '¿Anular esta venta? El stock vuelve y $cuando bajan '
        '${dinero(pedido.totalCentavos, simbolo: _simbolo)}.';
  }

  static String anulada(int lineasSinDevolver) {
    if (lineasSinDevolver == 0) return 'Venta anulada.';
    final lineas = lineasSinDevolver == 1
        ? '1 producto ya no existe'
        : '$lineasSinDevolver productos ya no existen';
    return 'Venta anulada. $lineas: su stock no se pudo devolver.';
  }

  static const String yaAnulada = 'Esta venta ya estaba anulada.';

  static String vencidos(ResultadoCancelarVencidos r) {
    if (r.canceladas == 0 && r.omitidas == 0 && r.fallidas == 0) {
      return 'No hay pedidos vencidos.';
    }
    final partes = <String>[];
    if (r.canceladas > 0) {
      partes.add(
        r.canceladas == 1
            ? 'Se canceló 1 pedido.'
            : 'Se cancelaron ${r.canceladas} pedidos.',
      );
    }
    if (r.omitidas > 0) {
      partes.add(
        r.omitidas == 1
            ? '1 ya no estaba nuevo y no se tocó.'
            : '${r.omitidas} ya no estaban nuevos y no se tocaron.',
      );
    }
    if (r.fallidas > 0) {
      partes.add(
        r.fallidas == 1
            ? '1 no se pudo cancelar: revisa tu conexión.'
            : '${r.fallidas} no se pudieron cancelar: revisa tu conexión.',
      );
    }
    return partes.join(' ');
  }
}
