import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/texto_lineas_pedido.dart';
import '../../application/services/tiempo_transcurrido.dart';
import '../../application/services/transiciones_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import 'pildora_pedido.dart';

/// La tabla de pedidos de la versión PC: clave, cliente con teléfono, hace,
/// entrega con zona, productos, pago, estado y total. Con casillas para
/// elegir varios. La columna Productos se oculta si el ancho no alcanza.
/// Todo el texto es plano (viene de una tienda pública).
class TablaPedidos extends StatelessWidget {
  const TablaPedidos({
    super.key,
    required this.pedidos,
    required this.ahora,
    required this.seleccionadoId,
    required this.marcados,
    required this.conCasillas,
    required this.onAbrir,
    required this.onAlternar,
    required this.onMarcarTodos,
  });

  final List<Pedido> pedidos;
  final DateTime ahora;
  final String? seleccionadoId;
  final Set<String> marcados;
  final bool conCasillas;
  final ValueChanged<Pedido> onAbrir;
  final ValueChanged<String> onAlternar;
  final ValueChanged<bool> onMarcarTodos;

  static const double _anchoMinimoConProductos = 820;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final conProductos = c.maxWidth >= _anchoMinimoConProductos;
        final todos =
            pedidos.isNotEmpty && pedidos.every((p) => marcados.contains(p.id));
        final alguno = pedidos.any((p) => marcados.contains(p.id));
        return Column(
          children: [
            _Fila(
              cabecera: true,
              conProductos: conProductos,
              casilla: conCasillas
                  ? Checkbox(
                      tristate: true,
                      value: todos ? true : (alguno ? null : false),
                      onChanged: (_) => onMarcarTodos(!todos),
                    )
                  : null,
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
                conProductos: conProductos,
                seleccionado: pedido.id == seleccionadoId,
                marcado: marcados.contains(pedido.id),
                conCasilla: conCasillas,
                onAbrir: () => onAbrir(pedido),
                onAlternar: () => onAlternar(pedido.id),
              ),
          ],
        );
      },
    );
  }
}

// Anchos: las columnas con texto largo se reparten el resto con `flex`.
const double _anchoCasilla = 44;
const double _anchoClave = 84;
const double _anchoHace = 92;
const double _anchoEstado = 132;
const double _anchoTotal = 84;

class _Fila extends StatelessWidget {
  const _Fila({
    required this.celdas,
    required this.conProductos,
    this.cabecera = false,
    this.casilla,
  });

  final List<String> celdas;
  final bool conProductos;
  final bool cabecera;
  final Widget? casilla;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      color: AppColors.hint,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    Widget t(String s, {TextAlign a = TextAlign.left}) =>
        Text(s.toUpperCase(), style: estilo, textAlign: a);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: _anchoCasilla, child: casilla),
          SizedBox(width: _anchoClave, child: t(celdas[0])),
          Expanded(flex: 22, child: t(celdas[1])),
          SizedBox(width: _anchoHace, child: t(celdas[2])),
          Expanded(flex: 16, child: t(celdas[3])),
          if (conProductos) Expanded(flex: 26, child: t(celdas[4])),
          Expanded(flex: 14, child: t(celdas[5])),
          SizedBox(width: _anchoEstado, child: t(celdas[6])),
          SizedBox(
            width: _anchoTotal,
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
    required this.conProductos,
    required this.seleccionado,
    required this.marcado,
    required this.conCasilla,
    required this.onAbrir,
    required this.onAlternar,
  });

  final Pedido pedido;
  final DateTime ahora;
  final bool conProductos;
  final bool seleccionado;
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
    const base = TextStyle(color: AppColors.texto, fontSize: 13);
    const tenue = TextStyle(color: AppColors.hint, fontSize: 11);

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
      selected: seleccionado,
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
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.bordeSutil)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: _anchoCasilla,
                  child: conCasilla
                      ? Checkbox(value: marcado, onChanged: (_) => onAlternar())
                      : null,
                ),
                SizedBox(
                  width: _anchoClave,
                  child: Text(
                    pedido.clave,
                    style: base.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(flex: 22, child: doble(nombre, telefono)),
                SizedBox(
                  width: _anchoHace,
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
                    cobrado ? 'Pagado' : 'Sin cobrar',
                    estiloAbajo: tenue.copyWith(
                      color: cobrado ? AppColors.ok : AppColors.aviso,
                    ),
                  ),
                ),
                SizedBox(
                  width: _anchoEstado,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PildoraPedido.estado(
                      pedido.estado,
                      vencido: vencido,
                    ),
                  ),
                ),
                SizedBox(
                  width: _anchoTotal,
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
