import '../../domain/models/cobro_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/resumen_ventas_dia.dart';
import 'contadores_venta.dart';
import 'resumen_dia_pedidos.dart';

// ═════════════════════════════════════════════════════════════════════════
// CobrosDia
// ═════════════════════════════════════════════════════════════════════════
// La caja no miente: «porPago» (y con él «Efectivo en caja») cuenta la plata
// el día en que ENTRA, y lo entregado sin cobrar queda «por cobrar» en el día
// de la entrega. «Ventas de hoy» sigue contando lo entregado (ContadoresVenta).
//
//   alNacer    → venta de Caja: si nace cobrada, la plata entra hoy
//   alEntregar → si ya se cobró no suma nada; si se cobra al entregar, suma
//                hoy; si no, queda «por cobrar» hoy
//   alCobrar   → suma hoy y quita el «por cobrar» del día de la entrega
//   alQuitar   → cancelar o anular: resta lo guardado en `cobro` (no se
//                recalcula)
//   aplicar    → los ajustes sobre los resúmenes ya leídos
//
// Pedidos viejos (sin `cobro`): ya sumaron su forma de pago al entregarse, así
// que cobrarlos no suma otra vez y anularlos resta del día de la entrega.
// Funciones puras: las usan los repositorios dentro de su transacción.
// ═════════════════════════════════════════════════════════════════════════
abstract final class CobrosDia {
  /// Venta registrada en Caja: si nace cobrada, la plata ya está en el cajón.
  static PlanCobro alNacer(Pedido pedido, DateTime ahora) {
    if (pedido.estadoPago != EstadoPago.pagado) return PlanCobro.nada;
    return _contar(pedido, ResumenDiaPedidos.claveDia(ahora));
  }

  /// Al entregar. [cobradoAhora]: el pedido queda pagado al entregarse.
  static PlanCobro alEntregar(
    Pedido pedido, {
    required bool cobradoAhora,
    required DateTime ahora,
  }) {
    if (pedido.cobro?.contado ?? false) return PlanCobro.nada;
    final hoy = ResumenDiaPedidos.claveDia(ahora);
    if (cobradoAhora) return _contar(pedido, hoy);
    return PlanCobro(
      ajustes: [
        AjusteCobroDia(
          dia: hoy,
          porCobrarCentavos: pedido.totalCentavos,
          porCobrar: 1,
        ),
      ],
      cobro: CobroPedido(centavos: pedido.totalCentavos, porCobrarDia: hoy),
    );
  }

  /// Al marcarlo cobrado. Nada si ya estaba cobrado o si es un pedido viejo
  /// ya entregado (su forma de pago se sumó al entregarse).
  static PlanCobro alCobrar(Pedido pedido, DateTime ahora) {
    final cobro = pedido.cobro;
    if (pedido.estadoPago == EstadoPago.pagado) return PlanCobro.nada;
    if (cobro?.contado ?? false) return PlanCobro.nada;
    if (cobro == null && pedido.estado == EstadoPedido.entregado) {
      return PlanCobro.nada;
    }
    final hoy = ResumenDiaPedidos.claveDia(ahora);
    final contado = _contar(pedido, hoy);
    if (cobro == null || !cobro.pendiente) return contado;
    return PlanCobro(
      ajustes: [
        ...contado.ajustes,
        AjusteCobroDia(
          dia: cobro.porCobrarDia,
          porCobrarCentavos: -cobro.centavos,
          porCobrar: -1,
          cobradoPedidoId: pedido.id,
        ),
      ],
      cobro: CobroPedido(
        dia: hoy,
        pago: contado.cobro!.pago,
        centavos: pedido.totalCentavos,
        porCobrarDia: cobro.porCobrarDia,
      ),
    );
  }

  /// Al cancelar o anular: resta lo que se sumó. [diaEntrega] es el día en
  /// que se entregó (solo al anular): un pedido viejo sumó ahí su forma de
  /// pago.
  static PlanCobro alQuitar(Pedido pedido, {String diaEntrega = ''}) {
    final cobro = pedido.cobro;
    if (cobro == null) {
      if (diaEntrega.isEmpty || pedido.estado != EstadoPedido.entregado) {
        return PlanCobro.nada;
      }
      return PlanCobro(
        ajustes: [
          AjusteCobroDia(
            dia: diaEntrega,
            pago: ContadoresVenta.clavePago(pedido.metodoPago),
            cobradoCentavos: -pedido.totalCentavos,
          ),
        ],
      );
    }
    return PlanCobro(
      ajustes: [
        if (cobro.contado)
          AjusteCobroDia(
            dia: cobro.dia,
            pago: cobro.pago,
            cobradoCentavos: -cobro.centavos,
          ),
        if (cobro.pendiente)
          AjusteCobroDia(
            dia: cobro.porCobrarDia,
            porCobrarCentavos: -cobro.centavos,
            porCobrar: -1,
          ),
      ],
    );
  }

  /// Aplica [ajustes] a los resúmenes ya leídos (por día). Nada baja de 0 y
  /// lo que llega a 0 se quita de «porPago».
  static Map<String, ResumenVentasDia> aplicar(
    Map<String, ResumenVentasDia> resumenes,
    List<AjusteCobroDia> ajustes,
  ) {
    final copia = {...resumenes};
    for (final a in ajustes) {
      final r = copia[a.dia] ?? ResumenVentasDia.vacio(a.dia);
      final c = r.contadores;
      final porPago = {...c.porPago};
      if (a.pago.isNotEmpty && a.cobradoCentavos != 0) {
        final nuevo = _piso((porPago[a.pago] ?? 0) + a.cobradoCentavos);
        if (nuevo == 0) {
          porPago.remove(a.pago);
        } else {
          porPago[a.pago] = nuevo;
        }
      }
      copia[a.dia] = r.copyWith(
        contadores: c.conCobros(
          porPago: porPago,
          porCobrarCentavos: _piso(c.porCobrarCentavos + a.porCobrarCentavos),
          porCobrar: _piso(c.porCobrar + a.porCobrar),
        ),
        ultimosEntregados: a.cobradoPedidoId.isEmpty
            ? r.ultimosEntregados
            : [
                for (final e in r.ultimosEntregados)
                  e.pedidoId == a.cobradoPedidoId ? e.comoCobrado() : e,
              ],
      );
    }
    return copia;
  }

  /// La plata del pedido entra en la caja de [dia].
  static PlanCobro _contar(Pedido pedido, String dia) {
    final pago = ContadoresVenta.clavePago(pedido.metodoPago);
    return PlanCobro(
      ajustes: [
        AjusteCobroDia(
          dia: dia,
          pago: pago,
          cobradoCentavos: pedido.totalCentavos,
        ),
      ],
      cobro: CobroPedido(dia: dia, pago: pago, centavos: pedido.totalCentavos),
    );
  }

  static int _piso(int valor) => valor < 0 ? 0 : valor;
}
