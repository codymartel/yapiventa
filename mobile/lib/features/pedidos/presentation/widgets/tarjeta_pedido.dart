import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/texto_lineas_pedido.dart';
import '../../application/services/tiempo_transcurrido.dart';
import '../../domain/models/pedido.dart';
import 'pildora_pedido.dart';

/// Un pedido en la lista: quién, cuándo, qué pidió y cuánto. Todo es texto
/// plano (viene de una tienda pública).
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
    final borde = vencido
        ? AppColors.error.withValues(alpha: 0.5)
        : seleccionado
        ? AppColors.blueLt
        : AppColors.bordeSutil;

    return Semantics(
      button: true,
      label:
          'Pedido ${pedido.clave} de $nombre, ${pedido.estado.etiqueta}, '
          '${MensajesAccionPedido.dinero(pedido.totalCentavos)}',
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borde, width: seleccionado ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Inicial(nombre: nombre, vencido: vencido),
                  const SizedBox(width: 12),
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
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pedido.clave,
                              style: const TextStyle(
                                color: AppColors.hint,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            PildoraPedido.estado(
                              pedido.estado,
                              vencido: vencido,
                            ),
                            PildoraPedido(
                              texto: esDelivery ? 'Delivery' : 'Recojo',
                              color: AppColors.muted,
                              icono: esDelivery
                                  ? Icons.local_shipping_outlined
                                  : Icons.storefront_outlined,
                            ),
                            Text(
                              vencido
                                  ? '${TiempoTranscurrido.hace(pedido.fecha, ahora)} sin confirmar'
                                  : TiempoTranscurrido.hace(
                                      pedido.fecha,
                                      ahora,
                                    ),
                              style: TextStyle(
                                color: vencido
                                    ? AppColors.error
                                    : AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          TextoLineasPedido.resumen(pedido.lineas),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    MensajesAccionPedido.dinero(pedido.totalCentavos),
                    style: const TextStyle(
                      color: AppColors.azulTexto,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
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
  const _Inicial({required this.nombre, required this.vencido});

  final String nombre;
  final bool vencido;

  @override
  Widget build(BuildContext context) {
    final color = vencido ? AppColors.error : AppColors.azulTexto;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        nombre.characters.first.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
