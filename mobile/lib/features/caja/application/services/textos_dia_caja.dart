import 'package:mobile/features/pedidos/application/services/mensajes_accion_pedido.dart';

import '../../domain/models/dia_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextosDiaCaja
// ═════════════════════════════════════════════════════════════════════════
// Lo que lee el cajero en los números del día: montos con coma y símbolo,
// «13 ventas», «1 gasto», y lo vendido separado en LOCAL (mostrador) y
// TIENDA WEB. Todo sale del resumen ya leído: aquí no se suma nada que no
// venga de él. Funciones puras.
// ═════════════════════════════════════════════════════════════════════════
abstract final class TextosDiaCaja {
  /// Símbolo del MVP (solo Perú). Único lugar de este archivo.
  static const String _simbolo = 'S/';

  /// «S/ 12,00»; un negativo sale «− S/ 10,00» (el signo nunca se pierde).
  static String plata(int centavos) {
    final texto = MensajesAccionPedido.dinero(
      centavos.abs(),
      simbolo: _simbolo,
    );
    return centavos < 0 ? '− $texto' : texto;
  }

  /// «12,00», sin símbolo (para filas compactas).
  static String numero(int centavos) {
    final texto = MensajesAccionPedido.dinero(centavos.abs());
    return centavos < 0 ? '− $texto' : texto;
  }

  static String cuantasVentas(int entregados) => switch (entregados) {
    <= 0 => 'sin ventas',
    1 => '1 venta',
    _ => '$entregados ventas',
  };

  static String cuantosGastos(int gastos) => switch (gastos) {
    <= 0 => 'ninguno',
    1 => '1 gasto',
    _ => '$gastos gastos',
  };

  /// Bajo «Ventas de hoy» en PC: «4 ventas · S/ 40,00 por cobrar» (lo de
  /// por cobrar solo si hay algo entregado sin cobrar).
  static String notaVentas(DiaCaja dia) {
    final ventas = cuantasVentas(dia.ventas.entregados);
    if (dia.porCobrarCentavos <= 0) return ventas;
    return '$ventas · ${plata(dia.porCobrarCentavos)} por cobrar';
  }

  /// Lo vendido en el mostrador hoy.
  static int localCentavos(DiaCaja dia) =>
      dia.ventas.contadores.mostradorCentavos;

  /// Lo entregado de la tienda web hoy (el total menos lo del mostrador).
  static int webCentavos(DiaCaja dia) {
    final web = dia.ventasCentavos - localCentavos(dia);
    return web < 0 ? 0 : web;
  }

  /// Bajo «Efectivo en caja»: avisa con texto cuando salió más de lo que
  /// entró (no solo con color).
  static String notaEfectivo(DiaCaja dia) =>
      dia.efectivoCentavos < 0 ? 'salió más de lo que entró hoy' : 'de hoy';
}
