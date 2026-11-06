import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/texto_lineas_pedido.dart';
import '../../application/services/tiempo_transcurrido.dart';
import '../../application/services/transiciones_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import 'pildora_pedido.dart';

/// La tabla de pedidos de PC y de TV: clave, cliente con teléfono, hace,
/// entrega con zona, productos, pago, estado y total. En PC lleva casillas
/// para elegir varios; en TV ([escala] mayor y [alturaFila] fija) marca con un
/// borde el pedido que tiene el foco del control remoto. La columna Productos
/// se oculta si el ancho no alcanza. Todo el texto es plano (viene de una
/// tienda pública).
class TablaPedidos extends StatelessWidget {
  const TablaPedidos({
    super.key,
    required this.pedidos,
    required this.ahora,
    required this.seleccionadoId,
    required this.onAbrir,
    this.marcados = const {},
    this.conCasillas = false,
    this.onAlternar,
    this.onMarcarTodos,
    this.escala = 1,
    this.alturaFila,
    this.focoId,
    this.anchoMinimoProductos,
  });

  final List<Pedido> pedidos;
  final DateTime ahora;
  final String? seleccionadoId;
  final ValueChanged<Pedido> onAbrir;
  final Set<String> marcados;
  final bool conCasillas;
  final ValueChanged<String>? onAlternar;
  final ValueChanged<bool>? onMarcarTodos;

  /// 1 en PC; 1,5 en TV (letra de 20 px o más).
  final double escala;

  /// Altura fija de cada fila (TV: para mover el foco con las flechas).
  final double? alturaFila;

  /// El pedido que tiene el foco del control remoto (TV).
  final String? focoId;

  /// Ancho mínimo para mostrar la columna Productos (por defecto, 820 por la
  /// escala).
  final double? anchoMinimoProductos;

  static const double _anchoMinimoConProductos = 820;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final conProductos =
            c.maxWidth >=
            (anchoMinimoProductos ?? _anchoMinimoConProductos * escala);
        final todos =
            pedidos.isNotEmpty && pedidos.every((p) => marcados.contains(p.id));
        final alguno = pedidos.any((p) => marcados.contains(p.id));
        return Column(
          children: [
            _Fila(
              escala: escala,
              conProductos: conProductos,
              casilla: conCasillas
                  ? Checkbox(
                      tristate: true,
                      value: todos ? true : (alguno ? null : false),
                      onChanged: (_) => onMarcarTodos?.call(!todos),
                    )
                  : null,
              conEspacioCasilla: conCasillas,
              celdas: const [
                'Clave',
                'Cliente',
                'Hace',
                'Entrega',
                'Productos',
                'Pago',
                'Estado',
                'Total',
              ],
            ),
            const Divider(height: 1, color: AppColors.dim),
            for (final pedido in pedidos)
              _FilaPedido(
                pedido: pedido,
                ahora: ahora,
                escala: escala,
                alturaFila: alturaFila,
                conProductos: conProductos,
                seleccionado: pedido.id == seleccionadoId,
                enFoco: pedido.id == focoId,
                marcado: marcados.contains(pedido.id),
                conCasilla: conCasillas,
                onAbrir: () => onAbrir(pedido),
                onAlternar: () => onAlternar?.call(pedido.id),
              ),
          ],
        );
      },
    );
  }
}

// Anchos base (PC): las columnas con texto largo se reparten el resto con
// `flex`. En TV se multiplican por la escala.
const double _anchoCasilla = 44;
const double _anchoClave = 84;
const double _anchoHace = 92;
const double _anchoEstado = 132;
const double _anchoTotal = 84;

class _Fila extends StatelessWidget {
  const _Fila({
    required this.celdas,
    required this.conProductos,
    required this.escala,
    required this.conEspacioCasilla,
    this.casilla,
  });

  final List<String> celdas;
  final bool conProductos;
  final double escala;
  final bool conEspacioCasilla;
  final Widget? casilla;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      color: AppColors.hint,
      fontSize: 11 * escala,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    Widget t(String s, {TextAlign a = TextAlign.left}) =>
        Text(s.toUpperCase(), style: estilo, textAlign: a);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * escala),
      child: Row(
        children: [
          if (conEspacioCasilla)
            SizedBox(width: _anchoCasilla * escala, child: casilla),
          SizedBox(width: _anchoClave * escala, child: t(celdas[0])),
          Expanded(flex: 22, child: t(celdas[1])),
          SizedBox(width: _anchoHace * escala, child: t(celdas[2])),
          Expanded(flex: 16, child: t(celdas[3])),
          if (conProductos) Expanded(flex: 26, child: t(celdas[4])),
          Expanded(flex: 14, child: t(celdas[5])),
          SizedBox(width: _anchoEstado * escala, child: t(celdas[6])),
          SizedBox(
            width: _anchoTotal * escala,
            child: t(celdas[7], a: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _FilaPedido extends StatelessWidget {
  const _FilaPedido({
    required this.pedido,
    required this.ahora,
    required this.escala,
    required this.alturaFila,
    required this.conProductos,
    required this.seleccionado,
    required this.enFoco,
    required this.marcado,
    required this.conCasilla,
    required this.onAbrir,
    required this.onAlternar,
  });

  final Pedido pedido;
  final DateTime ahora;
  final double escala;
  final double? alturaFila;
  final bool conProductos;
  final bool seleccionado;
  final bool enFoco;
  final bool marcado;
  final bool conCasilla;
  final VoidCallback onAbrir;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final vencido = TransicionesPedido.estaVencido(pedido, ahora);
    final nombre = pedido.cliente.nombre.trim().isEmpty
        ? 'Cliente'
        : pedido.cliente.nombre.trim();
    final telefono = pedido.cliente.telefono.trim();
    final esDelivery = pedido.tipoEntrega == TipoEntrega.delivery;
    final cobrado = pedido.estadoPago == EstadoPago.pagado;
    final reembolsoPendiente =
        pedido.estado == EstadoPedido.cancelado &&
        pedido.reembolso == EstadoReembolso.pendiente;
    final base = TextStyle(color: AppColors.texto, fontSize: 13 * escala);
    final tenue = TextStyle(color: AppColors.hint, fontSize: 11 * escala);

    Widget doble(String arriba, String abajo, {TextStyle? estiloAbajo}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              arriba,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base,
            ),
            if (abajo.isNotEmpty)
              Text(
                abajo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: estiloAbajo ?? tenue,
              ),
          ],
        );

    return Semantics(
      button: true,
      selected: seleccionado || enFoco,
      label:
          'Pedido ${pedido.clave} de $nombre, ${pedido.estado.etiqueta}, '
          '${MensajesAccionPedido.dinero(pedido.totalCentavos)}',
      child: Material(
        color: seleccionado
            ? AppColors.blue.withValues(alpha: 0.18)
            : Colors.transparent,
        child: InkWell(
          onTap: onAbrir,
          child: Container(
            height: alturaFila,
            constraints: alturaFila == null
                ? BoxConstraints(minHeight: 52 * escala)
                : null,
            decoration: BoxDecoration(
              border: enFoco
                  ? Border.all(color: Colors.white, width: 3)
                  : Border(bottom: BorderSide(color: AppColors.bordeSutil)),
            ),
            padding: EdgeInsets.symmetric(vertical: 6 * escala),
            child: Row(
              children: [
                if (conCasilla)
                  SizedBox(
                    width: _anchoCasilla * escala,
                    child: Checkbox(
                      value: marcado,
                      onChanged: (_) => onAlternar(),
                    ),
                  ),
                SizedBox(
                  width: _anchoClave * escala,
                  child: Text(
                    pedido.clave,
                    style: base.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(flex: 22, child: doble(nombre, telefono)),
                SizedBox(
                  width: _anchoHace * escala,
                  child: Text(
                    TiempoTranscurrido.hace(pedido.fecha, ahora),
                    style: base.copyWith(
                      color: vencido ? AppColors.error : AppColors.texto,
                    ),
                  ),
                ),
                Expanded(
                  flex: 16,
                  child: doble(
                    esDelivery ? 'Delivery' : 'Recojo',
                    esDelivery ? pedido.zona.trim() : 'en el local',
                  ),
                ),
                if (conProductos)
                  Expanded(
                    flex: 26,
                    child: Text(
                      TextoLineasPedido.resumen(pedido.lineas),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(color: AppColors.muted),
                    ),
                  ),
                Expanded(
                  flex: 14,
                  child: doble(
                    pedido.metodoPago.trim().isEmpty
                        ? '—'
                        : pedido.metodoPago.trim(),
                    reembolsoPendiente
                        ? 'Reembolso pendiente'
                        : (cobrado ? 'Pagado' : 'Sin cobrar'),
                    estiloAbajo: tenue.copyWith(
                      color: cobrado && !reembolsoPendiente
                          ? AppColors.ok
                          : AppColors.aviso,
                    ),
                  ),
                ),
                SizedBox(
                  width: _anchoEstado * escala,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PildoraPedido.estado(
                      pedido.estado,
                      vencido: vencido,
                      escala: escala,
                    ),
                  ),
                ),
                SizedBox(
                  width: _anchoTotal * escala,
                  child: Text(
                    MensajesAccionPedido.dinero(pedido.totalCentavos),
                    textAlign: TextAlign.right,
                    style: base.copyWith(
                      color: AppColors.azulTexto,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
