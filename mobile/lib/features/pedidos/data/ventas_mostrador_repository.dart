import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../application/services/calculo_stock_pedido.dart';
import '../application/services/cobros_dia.dart';
import '../application/services/contadores_venta.dart';
import '../application/services/resumen_dia_pedidos.dart';
import '../application/services/resumen_ventas_dia_calculo.dart';
import '../application/services/transiciones_pedido.dart';
import '../application/services/verificacion_total_pedido.dart';
import '../domain/models/estado_pedido.dart';
import '../domain/models/pedido.dart';
import '../domain/repositories/repositorio_ventas_mostrador.dart';
import 'ayudas_pedidos_firestore.dart';
import 'pedido_mapper.dart';

/// Ventas de mostrador (Caja). Registrar una venta mueve el stock de varios
/// productos, crea el pedido y suma al resumen del día: va en UNA transacción
/// (todo o nada), con todas las lecturas antes de las escrituras.
///
/// Lecturas: los productos de la venta (más las partes de sus combos) y, si la
/// venta queda entregada o cobrada, 1 resumen del día. Escrituras: 1 pedido,
/// los productos cuyo stock cambia y 1 resumen. Una venta de 2 productos en el
/// local: 3 lecturas y 4 escrituras.
///
///   En el local y recojo → nace ENTREGADA y cobrada, y suma a las ventas y
///                          a la caja.
///   Delivery             → nace CONFIRMADA (stock ya descontado) y sigue en
///                          Pedidos; suma a las ventas cuando se entregue. Si
///                          se cobró en el mostrador, la plata entra hoy.
class VentasMostradorRepository implements RepositorioVentasMostrador {
  VentasMostradorRepository({FirebaseFirestore? db, DateTime Function()? reloj})
    : _db = db ?? FirebaseFirestore.instance,
      _ayudas = AyudasPedidosFirestore(
        db: db ?? FirebaseFirestore.instance,
        reloj: reloj ?? DateTime.now,
      );

  final FirebaseFirestore _db;
  final AyudasPedidosFirestore _ayudas;

  @override
  Future<ResultadoVentaMostrador> registrar(
    String negocioId,
    SolicitudVentaMostrador solicitud,
  ) {
    _comprobarSolicitud(solicitud);
    final ref = _ayudas.pedidos(negocioId).doc(solicitud.idVenta.trim());
    final entregada = solicitud.tipoEntrega != TipoEntrega.delivery;

    return _db.runTransaction((tx) async {
      // Un toque repetido: la venta ya está registrada, no se hace nada más.
      final existente = await tx.get(ref);
      if (existente.exists) {
        return ResultadoVentaMostrador(
          pedidoId: ref.id,
          clave: _ayudas.pedido(existente).clave,
          yaRegistrada: true,
        );
      }

      // Todas las lecturas primero: los productos de la venta y, si hay
      // combos, las partes de cada combo.
      final productos = <String, Producto>{};
      final leidos = <String>{};
      Future<void> leer(Iterable<String> ids) async {
        for (final id in ids) {
          if (!leidos.add(id)) continue;
          final producto = await _ayudas.leerProducto(tx, negocioId, id);
          if (producto != null) productos[id] = producto;
        }
      }

      await leer(CalculoStockPedido.idsDeLineas(solicitud.lineas));
      await leer([
        for (final p in productos.values.toList())
          if (p.esCombo) ...CalculoStockPedido.idsDePartes(p),
      ]);
      Producto? buscar(String id) => productos[id];

      final calculo = CalculoStockPedido.calcular(solicitud.lineas, buscar);
      if (!calculo.ok) {
        return ResultadoVentaMostrador(
          faltas: calculo.faltas,
          sinProducto: calculo.sinProducto,
        );
      }

      // El precio de hoy debe ser el que vio el cajero: si cambió, no se cobra.
      final verificacion = CalculoPedido.verificar(
        Pedido(
          id: ref.id,
          lineas: solicitud.lineas,
          deliveryCentavos: solicitud.deliveryCentavos,
          descuentoCentavos: solicitud.descuentoCentavos,
          subtotalCentavos: solicitud.subtotalCentavos,
          totalCentavos: solicitud.totalCentavos,
        ),
        buscar,
      );
      if (verificacion.difiere || verificacion.lineasCambiadas.isNotEmpty) {
        return ResultadoVentaMostrador(
          precioCambio: true,
          totalActualCentavos: verificacion.totalActualCentavos,
          lineasCambiadas: verificacion.lineasCambiadas,
        );
      }

      final ahora = _ayudas.ahora();
      final estado = entregada
          ? EstadoPedido.entregado
          : EstadoPedido.confirmado;
      final pedido = Pedido(
        id: ref.id,
        clave: PedidoMapper.claveDeId(ref.id),
        estado: estado,
        origen: OrigenPedido.mostrador,
        tipoEntrega: solicitud.tipoEntrega,
        enLocal: entregada && solicitud.enLocal,
        cliente: solicitud.cliente,
        zona: solicitud.zona.trim(),
        deliveryCentavos: solicitud.deliveryCentavos,
        descuentoCentavos: solicitud.descuentoCentavos,
        subtotalCentavos: solicitud.subtotalCentavos,
        totalCentavos: solicitud.totalCentavos,
        lineas: solicitud.lineas,
        metodoPago: solicitud.metodoPago.trim(),
        estadoPago: (!entregada && solicitud.cobrarAlEntregar)
            ? EstadoPago.pendiente
            : EstadoPago.pagado,
        notas: solicitud.notas.trim(),
        stockDescontado: calculo.descuentos,
        historial: [
          CambioEstado(estado: EstadoPedido.confirmado, fecha: ahora),
          if (entregada)
            CambioEstado(estado: EstadoPedido.entregado, fecha: ahora),
        ],
      );

      // El resumen del día se lee ANTES de escribir (regla de las
      // transacciones) y se guarda el valor ya sumado. Si la venta nace
      // cobrada (aunque sea delivery), la plata entra hoy a la caja.
      final hoy = ResumenDiaPedidos.claveDia(ahora);
      final plan = CobrosDia.alNacer(pedido, ahora);
      final resumenes = await _ayudas.leerResumenes(tx, negocioId, {
        if (entregada) hoy,
        ...plan.dias,
      });

      // ── Escrituras ──────────────────────────────────────────────────
      // `vendidos` sube 1 por producto de las líneas (cuenta ventas, no
      // unidades). Los combos no tienen stock propio: solo suben `vendidos`.
      final deLasLineas = {
        for (final l in solicitud.lineas)
          if (l.productoId.isNotEmpty) l.productoId,
      };
      final conStock = {for (final d in calculo.descuentos) d.productoId};
      for (final id in conStock) {
        final nuevo = CalculoStockPedido.aplicar(
          productos[id]!,
          calculo.descuentos,
          devolver: false,
        ).producto;
        tx.update(_ayudas.producto(negocioId, id), {
          ..._ayudas.camposDeStock(nuevo),
          if (deLasLineas.contains(id)) 'vendidos': FieldValue.increment(1),
        });
      }
      for (final id in deLasLineas.difference(conStock)) {
        tx.update(_ayudas.producto(negocioId, id), {
          'vendidos': FieldValue.increment(1),
        });
      }

      tx.set(ref, {
        'negocioId': negocioId.trim(),
        'clave': pedido.clave,
        'estado': estado.valor,
        'origen': OrigenPedido.mostrador.valor,
        'enLocal': pedido.enLocal,
        'tipoEntrega': pedido.tipoEntrega.valor,
        'fecha': FieldValue.serverTimestamp(),
        'cliente': PedidoMapper.clienteAMapa(pedido.cliente),
        if (pedido.zona.isNotEmpty) 'zona': pedido.zona,
        'deliveryCentavos': pedido.deliveryCentavos,
        'descuentoCentavos': pedido.descuentoCentavos,
        'subtotalCentavos': pedido.subtotalCentavos,
        'totalCentavos': pedido.totalCentavos,
        'lineas': PedidoMapper.lineasAMapas(pedido.lineas),
        'metodoPago': pedido.metodoPago,
        'estadoPago': pedido.estadoPago.valor,
        if (pedido.notas.isNotEmpty) 'notas': pedido.notas,
        'stockDescontado': PedidoMapper.descuentosAMapas(calculo.descuentos),
        'reembolso': EstadoReembolso.ninguno.valor,
        'historial': PedidoMapper.historialAMapas(pedido.historial),
        if (plan.cobro case final cobro?)
          'cobro': PedidoMapper.cobroAMapa(cobro),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      if (entregada) {
        final actual = resumenes[hoy]!;
        resumenes[hoy] = actual.copyWith(
          ventasCentavos: actual.ventasCentavos + pedido.totalCentavos,
          entregados: actual.entregados + 1,
          ultimosEntregados: ResumenVentasDiaCalculo.conNuevoEntregado(
            actual.ultimosEntregados,
            ResumenVentasDiaCalculo.entregadoDe(pedido, ahora),
          ),
          contadores: ContadoresVenta.sumar(
            actual.contadores,
            ContadoresVenta.aporteDe(pedido, ahora),
          ),
        );
      }
      _ayudas.guardarResumenes(
        tx,
        negocioId,
        CobrosDia.aplicar(resumenes, plan.ajustes),
      );

      return ResultadoVentaMostrador(
        pedidoId: ref.id,
        clave: pedido.clave,
        registrada: true,
        descuentos: calculo.descuentos,
      );
    });
  }

  /// Lecturas: el pedido, el resumen del día de la venta y los productos que
  /// se descontaron. Escrituras: el pedido, los productos y el resumen. Una
  /// venta de 2 productos: 4 lecturas y 4 escrituras.
  @override
  Future<ResultadoAnulacion> anular(String negocioId, String pedidoId) {
    if (pedidoId.trim().isEmpty) {
      throw ArgumentError.value(pedidoId, 'pedidoId', 'La venta no tiene id.');
    }
    final ref = _ayudas.pedidos(negocioId).doc(pedidoId.trim());
    return _db.runTransaction((tx) async {
      final pedido = await _ayudas.leerPedido(tx, ref);
      // Un toque repetido (u otro cajero): no se resta dos veces.
      if (pedido.anulada) return const ResultadoAnulacion(yaAnulada: true);
      if (!TransicionesPedido.puedeAnular(pedido)) {
        throw StateError('Esta venta ya no se puede anular.');
      }

      // Se resta del día en que se vendió (no de hoy), con la misma hora que
      // se usó al sumar.
      // Lo cobrado se resta del día en que entró la plata (puede ser otro).
      final ahora = _ayudas.ahora();
      final momento = ResumenVentasDiaCalculo.momentoDeEntrega(pedido) ?? ahora;
      final diaVenta = ResumenDiaPedidos.claveDia(momento);
      final plan = CobrosDia.alQuitar(pedido, diaEntrega: diaVenta);
      final resumenes = await _ayudas.leerResumenes(tx, negocioId, {
        diaVenta,
        ...plan.dias,
      });

      // Se devuelve lo guardado en el pedido (no se recalcula).
      final sinDevolver = await _ayudas.devolverStock(
        tx,
        negocioId,
        pedido,
        restarVendidos: true,
      );

      // ── Escrituras ──────────────────────────────────────────────────
      tx.update(ref, {
        'estado': EstadoPedido.cancelado.valor,
        'historial': _ayudas.historialCon(pedido, EstadoPedido.cancelado),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      final actual = resumenes[diaVenta]!;
      resumenes[diaVenta] = actual.copyWith(
        ventasCentavos: _noNegativo(
          actual.ventasCentavos - pedido.totalCentavos,
        ),
        entregados: _noNegativo(actual.entregados - 1),
        ultimosEntregados: ResumenVentasDiaCalculo.sinEntregado(
          actual.ultimosEntregados,
          pedido.id,
        ),
        contadores: ContadoresVenta.restar(
          actual.contadores,
          ContadoresVenta.aporteDe(pedido, momento),
        ),
      );
      _ayudas.guardarResumenes(
        tx,
        negocioId,
        CobrosDia.aplicar(resumenes, plan.ajustes),
      );
      return ResultadoAnulacion(sinDevolver: sinDevolver);
    });
  }

  static int _noNegativo(int valor) => valor < 0 ? 0 : valor;

  /// Errores de programación (no del cajero): la cuenta debe cuadrar.
  void _comprobarSolicitud(SolicitudVentaMostrador s) {
    if (s.idVenta.trim().isEmpty) {
      throw ArgumentError.value(s.idVenta, 'idVenta', 'La venta no tiene id.');
    }
    if (s.lineas.isEmpty) {
      throw ArgumentError.value(
        s.lineas,
        'lineas',
        'La venta no tiene líneas.',
      );
    }
    final subtotal = CalculoPedido.subtotal(s.lineas);
    final total = CalculoPedido.total(
      subtotalCentavos: subtotal,
      deliveryCentavos: s.deliveryCentavos,
      descuentoCentavos: s.descuentoCentavos,
    );
    if (subtotal != s.subtotalCentavos || total != s.totalCentavos) {
      throw ArgumentError('La cuenta de la venta no cuadra.');
    }
  }
}
