import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/texto_lineas_pedido.dart';
import '../../application/services/tiempo_transcurrido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import 'pildora_pedido.dart';

/// Un pedido en la lista, como en la maqueta: inicial de color, nombre con su
/// clave, etiquetas (estado y entrega), «hace X», lo pedido y el total. El
/// borde dice el estado: ámbar si es nuevo, rojo si está vencido, azul grueso
/// si es el elegido. Todo es texto plano (viene de una tienda pública).
class TarjetaPedido extends StatelessWidget {
  const TarjetaPedido({
    super.key,
    required this.pedido,
    required this.ahora,
    required this.vencido,
    this.seleccionado = false,
    this.onTap,
  });

  final Pedido pedido;
  final DateTime ahora;
  final bool vencido;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nombre = pedido.cliente.nombre.trim().isEmpty
        ? 'Cliente'
        : pedido.cliente.nombre.trim();
    final esDelivery = pedido.tipoEntrega == TipoEntrega.delivery;
    final esNuevo = pedido.estado == EstadoPedido.nuevo;
    final acento = vencido
        ? AppColors.error
        : esNuevo
        ? AppColors.aviso
        : AppColors.azulTexto;
    final borde = seleccionado
        ? AppColors.blueLt
        : vencido
        ? AppColors.error.withValues(alpha: 0.5)
        : esNuevo
        ? AppColors.aviso.withValues(alpha: 0.55)
        : AppColors.bordeMedio;

    return Semantics(
      button: true,
      label:
          'Pedido ${pedido.clave} de $nombre, ${pedido.estado.etiqueta}, '
          '${MensajesAccionPedido.dinero(pedido.totalCentavos)}',
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borde, width: seleccionado ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Inicial(nombre: nombre, color: acento),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              pedido.clave,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            PildoraPedido.estado(
                              pedido.estado,
                              vencido: vencido,
                            ),
                            if (pedido.estado == EstadoPedido.cancelado &&
                                pedido.reembolso == EstadoReembolso.pendiente)
                              const PildoraPedido(
                                texto: 'Reembolso pendiente',
                                color: AppColors.aviso,
                              ),
                            if (!vencido)
                              PildoraPedido.neutra(
                                texto: esDelivery ? 'Delivery' : 'Recojo',
                                icono: esDelivery
                                    ? Icons.local_shipping_outlined
                                    : Icons.storefront_outlined,
                              ),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                vencido
                                    ? '${TiempoTranscurrido.hace(pedido.fecha, ahora)} sin confirmar'
                                    : TiempoTranscurrido.hace(
                                        pedido.fecha,
                                        ahora,
                                      ),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!vencido) ...[
                          const SizedBox(height: 3),
                          Text(
                            TextoLineasPedido.resumen(pedido.lineas),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    MensajesAccionPedido.dinero(pedido.totalCentavos),
                    style: const TextStyle(
                      color: AppColors.azulTexto,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Inicial extends StatelessWidget {
  const _Inicial({required this.nombre, required this.color});

  final String nombre;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(
        nombre.characters.first.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
