import 'package:mobile/features/negocio/domain/models/metodo_pago_tipo.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';

import '../../domain/models/opciones_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// OpcionesCajaDesdeNegocio
// ═════════════════════════════════════════════════════════════════════════
// Lee de la configuración del negocio (el documento ya cargado en memoria: 0
// lecturas) lo que Caja necesita, y lo convierte UNA sola vez a enteros:
//
//   metodosPago   ['efectivo', 'yape'…]      → las formas de pago ACTIVAS
//   configPagos   {yape: {descuentoActivo,   → su descuento (porcentaje en
//                  tipoDescuento, valor…}}     centésimas de punto, o monto
//                                              fijo en céntimos)
//   delivery / deliveryZonas [{zona, costo}] → las zonas con su costo
//
// La configuración guarda soles con decimales; de aquí en adelante Caja solo
// trabaja con céntimos. Cada negocio tiene SUS formas de pago y SUS zonas:
// no hay una lista fija. Una forma de pago que Caja no conoce se muestra con
// su propio nombre. Lectura defensiva: lo raro se ignora. Función pura.
// ═════════════════════════════════════════════════════════════════════════
abstract final class OpcionesCajaDesdeNegocio {
  /// Tope de zonas que se muestran (un documento raro no llena la pantalla).
  static const int maximoZonas = 50;

  static List<OpcionPagoCaja> pagos(Map<String, dynamic> negocio) {
    final lista = negocio['metodosPago'];
    if (lista is! List) return const [];
    final configs = negocio['configPagos'];
    final opciones = <OpcionPagoCaja>[];
    final vistos = <String>{};
    for (final elemento in lista) {
      if (elemento is! String) continue;
      final id = elemento.trim().toLowerCase();
      if (id.isEmpty || !vistos.add(id)) continue;
      opciones.add(
        OpcionPagoCaja(
          id: id,
          etiqueta: MetodoPagoTipo.porId(id)?.nombre ?? _nombrePropio(elemento),
          descuento: _descuento(configs is Map ? configs[elemento] : null),
        ),
      );
    }
    return opciones;
  }

  /// Las zonas de delivery. Vacío si el negocio no hace delivery.
  static List<ZonaCaja> zonas(Map<String, dynamic> negocio) {
    if (negocio['delivery'] != true) return const [];
    final lista = negocio['deliveryZonas'];
    if (lista is! List) return const [];
    final zonas = <ZonaCaja>[];
    final vistas = <String>{};
    for (final elemento in lista) {
      if (elemento is! Map || zonas.length >= maximoZonas) continue;
      final nombre = '${elemento['zona'] ?? ''}'.trim();
      if (nombre.isEmpty || !vistas.add(nombre.toLowerCase())) continue;
      zonas.add(
        ZonaCaja(nombre: nombre, costoCentavos: _centavos(elemento['costo'])),
      );
    }
    return zonas;
  }

  static DescuentoPago _descuento(Object? config) {
    if (config is! Map || config['descuentoActivo'] != true) {
      return DescuentoPago.ninguno;
    }
    final valor = _centavos(config['valorDescuento']);
    if (valor <= 0) return DescuentoPago.ninguno;
    final minimo = _centavos(config['montoMinimo']);
    if (config['tipoDescuento'] == 'porcentaje') {
      // 5 % se guarda como 5.0 → 500 centésimas de punto. Nunca más de 100 %.
      return DescuentoPago.porcentaje(
        centesimas: valor > 10000 ? 10000 : valor,
        minimoCentavos: minimo,
      );
    }
    return DescuentoPago.montoFijo(centavos: valor, minimoCentavos: minimo);
  }

  /// Soles con decimales (número o texto) → céntimos enteros, redondeando
  /// UNA vez. Lo que no es un número, o es negativo, cuenta como 0.
  static int _centavos(Object? valor) {
    final numero = valor is num
        ? valor.toDouble()
        : double.tryParse('${valor ?? ''}'.replaceAll(',', '.'));
    if (numero == null || numero.isNaN || numero.isInfinite || numero <= 0) {
      return 0;
    }
    return (numero * 100).round();
  }

  /// «tarjeta bcp» → «Tarjeta bcp»: el nombre tal como lo escribió el
  /// vendedor, con la primera letra en mayúscula.
  static String _nombrePropio(String texto) {
    final limpio = texto.trim();
    return limpio[0].toUpperCase() + limpio.substring(1);
  }
}
