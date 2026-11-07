import 'package:mobile/features/pedidos/application/services/mensajes_accion_pedido.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';

// ═════════════════════════════════════════════════════════════════════════
// MensajesCobroCaja
// ═════════════════════════════════════════════════════════════════════════
// Los textos que lee el cajero al cobrar: qué faltó, por qué no se cobró o
// que se registró. Funciones puras. Los nombres vienen de los productos del
// negocio y se muestran como texto plano.
// ═════════════════════════════════════════════════════════════════════════
abstract final class MensajesCobroCaja {
  /// Símbolo del MVP (solo Perú). Único lugar de este archivo.
  static const String _simbolo = 'S/';

  static String dinero(int centavos) =>
      MensajesAccionPedido.dinero(centavos, simbolo: _simbolo);

  static String registrada(int totalCentavos) =>
      'Venta registrada · ${dinero(totalCentavos)}';

  static const String yaRegistrada = 'Esta venta ya estaba registrada.';

  static const String sinConexion =
      'No se pudo cobrar. Revisa tu conexión e inténtalo de nuevo: no se '
      'cobrará dos veces.';

  static const String ventasBloqueadas =
      'Espera a que termine de prepararse el catálogo.';

  /// Por qué NO se cobró (no se escribió nada). null si sí se registró.
  static String? noSeCobro(ResultadoRegistroVenta r) {
    final invalida = r.invalida;
    if (invalida != null) return invalida.mensaje;
    final res = r.resultado;
    if (res == null || res.registrada || res.yaRegistrada) return null;
    return bloqueo(res);
  }

  static String bloqueo(ResultadoVentaMostrador res) {
    if (res.precioCambio) {
      final total = res.totalActualCentavos;
      final cuales = res.lineasCambiadas.isEmpty
          ? ''
          : ' (cambió: ${res.lineasCambiadas.join(', ')})';
      final conTotal = total == null
          ? ''
          : ' Con los precios de hoy el total sería ${dinero(total)}.';
      return 'Los precios cambiaron$cuales.$conTotal Vuelve a agregar los '
          'productos para cobrar con el precio nuevo.';
    }
    final partes = <String>[];
    if (res.faltas.isNotEmpty) {
      final detalle = res.faltas
          .map((f) => '${f.nombre} (pides ${f.pide}, hay ${f.hay})')
          .join('; ');
      partes.add('No alcanza el stock: $detalle. No se cobró nada.');
    }
    if (res.sinProducto.isNotEmpty) {
      partes.add(
        'Ya no existe: ${res.sinProducto.join(', ')}. No se cobró nada.',
      );
    }
    return partes.isEmpty ? 'No se pudo cobrar.' : partes.join(' ');
  }
}
