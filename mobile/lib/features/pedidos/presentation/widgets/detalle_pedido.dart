import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/resumen_dia_pedidos.dart';
import '../../application/services/tiempo_transcurrido.dart';
import '../../application/services/transiciones_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import 'barra_progreso_pedido.dart';
import 'lineas_y_totales_pedido.dart';
import 'pildora_pedido.dart';

/// Lo que el vendedor puede hacer desde el detalle. Una acción null no se
/// muestra (por ejemplo, en el historial solo se mira).
class AccionesDetallePedido {
  const AccionesDetallePedido({
    this.onPrincipal,
    this.onCancelar,
    this.onMarcarCobrado,
    this.onWhatsapp,
    this.onReembolso,
  });

  final VoidCallback? onPrincipal;
  final VoidCallback? onCancelar;
  final VoidCallback? onMarcarCobrado;
  final VoidCallback? onWhatsapp;

  /// Solo en un cancelado que ya estaba pagado: avisa que se devolvió el dinero.
  final VoidCallback? onReembolso;
}

/// El detalle de un pedido: cliente, entrega, productos, cuenta y las
/// acciones al pie. Sirve igual en una hoja (celular) o en un panel (tableta).
/// Todo lo del cliente es texto plano.
class DetallePedido extends StatelessWidget {
  const DetallePedido({
    super.key,
    required this.pedido,
    required this.ahora,
    required this.vencido,
    required this.procesando,
    this.acciones = const AccionesDetallePedido(),
    this.completo = false,
  });

  final Pedido pedido;
  final DateTime ahora;
  final bool vencido;
  final bool procesando;
  final AccionesDetallePedido acciones;

  /// En PC se agrega el historial del pedido (cuándo cambió de estado).
  final bool completo;

  @override
  Widget build(BuildContext context) {
    final nombre = pedido.cliente.nombre.trim().isEmpty
        ? 'Cliente'
        : pedido.cliente.nombre.trim();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    pedido.clave,
                    style: const TextStyle(color: AppColors.hint),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PildoraPedido.estado(pedido.estado, vencido: vencido),
                  Text(
                    completo && pedido.fecha != null
                        ? 'llegó a las ${ResumenDiaPedidos.horaLima(pedido.fecha!)} · '
                              '${TiempoTranscurrido.hace(pedido.fecha, ahora)}'
                        : TiempoTranscurrido.hace(pedido.fecha, ahora),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BarraProgresoPedido(pedido: pedido),
              _Seccion('Cliente y entrega'),
              if (pedido.cliente.telefono.trim().isNotEmpty)
                _Dato(Icons.phone_outlined, pedido.cliente.telefono.trim()),
              _Dato(
                pedido.tipoEntrega == TipoEntrega.delivery
                    ? Icons.local_shipping_outlined
                    : Icons.storefront_outlined,
                _textoEntrega(),
              ),
              if (pedido.notas.trim().isNotEmpty)
                _Dato(
                  Icons.sticky_note_2_outlined,
                  'Nota del cliente: «${pedido.notas.trim()}»',
                ),
              _Dato(Icons.credit_card, _textoPago()),
              if (acciones.onMarcarCobrado != null &&
                  pedido.estadoPago == EstadoPago.pendiente &&
                  TransicionesPedido.puedeCambiarPago(pedido.estado))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: procesando ? null : acciones.onMarcarCobrado,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Marcar como cobrado'),
                  ),
                ),
              _Seccion('Productos y cuenta'),
              LineasYTotalesPedido(pedido: pedido),
              if (completo && pedido.historial.isNotEmpty) ...[
                _Seccion('Historial'),
                for (final cambio in pedido.historial)
                  _Dato(
                    Icons.schedule,
                    '${ResumenDiaPedidos.horaLima(cambio.fecha)} · '
                    '${cambio.estado.etiqueta}',
                  ),
              ],
              if (pedido.estado == EstadoPedido.cancelado &&
                  pedido.reembolso == EstadoReembolso.pendiente)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Reembolso pendiente: devuelve el dinero al cliente.',
                    style: TextStyle(color: AppColors.aviso),
                  ),
                ),
            ],
          ),
        ),
        _Pie(pedido: pedido, procesando: procesando, acciones: acciones),
      ],
    );
  }

  String _textoEntrega() {
    final lugar = [
      if (pedido.cliente.direccion.trim().isNotEmpty)
        pedido.cliente.direccion.trim(),
      if (pedido.zona.trim().isNotEmpty) pedido.zona.trim(),
    ].join(' · ');
    if (pedido.tipoEntrega == TipoEntrega.recojo) {
      return 'Recojo en el local';
    }
    final delivery = pedido.deliveryCentavos > 0
        ? ' (delivery ${MensajesAccionPedido.dinero(pedido.deliveryCentavos)})'
        : '';
    return lugar.isEmpty ? 'Delivery$delivery' : '$lugar$delivery';
  }

  String _textoPago() {
    final metodo = pedido.metodoPago.trim().isEmpty
        ? 'Sin método'
        : pedido.metodoPago.trim();
    final estado = pedido.estadoPago == EstadoPago.pagado
        ? 'Pagado'
        : 'Sin cobrar';
    return '$metodo · $estado';
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          color: AppColors.hint,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: const TextStyle(color: AppColors.texto)),
          ),
        ],
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({
    required this.pedido,
    required this.procesando,
    required this.acciones,
  });

  final Pedido pedido;
  final bool procesando;
  final AccionesDetallePedido acciones;

  @override
  Widget build(BuildContext context) {
    final etiqueta = TransicionesPedido.etiquetaBoton(
      pedido.estado,
      pedido.tipoEntrega,
    );
    final hayPrincipal = etiqueta.isNotEmpty && acciones.onPrincipal != null;
    final puedeCancelar =
        acciones.onCancelar != null &&
        TransicionesPedido.puedeCancelar(pedido.estado);
    final hayReembolso =
        acciones.onReembolso != null &&
        TransicionesPedido.puedeMarcarReembolsoHecho(pedido);
    if (!hayPrincipal &&
        !hayReembolso &&
        !puedeCancelar &&
        acciones.onWhatsapp == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.superficie,
        border: Border(top: BorderSide(color: AppColors.dim)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hayPrincipal)
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: procesando ? null : acciones.onPrincipal,
                child: procesando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(etiqueta),
              ),
            if (hayReembolso)
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: procesando ? null : acciones.onReembolso,
                child: const Text('Marcar reembolso hecho'),
              ),
            if (acciones.onWhatsapp != null || puedeCancelar)
              Padding(
                padding: EdgeInsets.only(
                  top: hayPrincipal || hayReembolso ? 8 : 0,
                ),
                child: Row(
                  children: [
                    if (acciones.onWhatsapp != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: acciones.onWhatsapp,
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    if (acciones.onWhatsapp != null && puedeCancelar)
                      const SizedBox(width: 8),
                    if (puedeCancelar)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            foregroundColor: AppColors.error,
                          ),
                          onPressed: procesando ? null : acciones.onCancelar,
                          child: const Text('Cancelar'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
