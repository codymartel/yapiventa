import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/indicadores_pedidos.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../domain/models/resumen_ventas_dia.dart';

/// Los 6 números del día de la versión PC (y TV): Nuevos, Activos, Por cobrar,
/// Vencidos, Ventas de hoy y Tiempo para confirmar. Los cuatro primeros salen
/// de lo cargado; los dos últimos, del resumen del día (1 documento).
class IndicadoresPc extends StatelessWidget {
  const IndicadoresPc({
    super.key,
    required this.indicadores,
    required this.conteoNuevos,
    required this.conteoActivos,
    required this.resumen,
  });

  final IndicadoresPedidos indicadores;
  final String conteoNuevos;
  final String conteoActivos;
  final ResumenVentasDia resumen;

  @override
  Widget build(BuildContext context) {
    final ticket = resumen.ticketCentavos;
    final minutos = resumen.minutosPromedioConfirmar;
    final masViejo = indicadores.minutosDelNuevoMasViejo;
    final tarjetas = <_Dato>[
      _Dato(
        valor: conteoNuevos,
        etiqueta: 'Nuevos',
        detalle: masViejo == null
            ? 'ninguno esperando'
            : 'el más viejo: $masViejo min',
        color: AppColors.aviso,
      ),
      _Dato(
        valor: conteoActivos,
        etiqueta: 'Activos',
        detalle: '${indicadores.enCamino} en camino',
        color: AppColors.azulTexto,
      ),
      _Dato(
        valor: MensajesAccionPedido.dinero(indicadores.porCobrarCentavos),
        etiqueta: 'Por cobrar (cargados)',
        detalle: indicadores.porCobrarPedidos == 1
            ? '1 pedido'
            : '${indicadores.porCobrarPedidos} pedidos',
        color: AppColors.aviso,
      ),
      _Dato(
        valor: '${indicadores.vencidos}',
        etiqueta: 'Vencidos (+12 h)',
        detalle: 'sin confirmar',
        color: indicadores.vencidos > 0 ? AppColors.error : AppColors.muted,
      ),
      _Dato(
        valor: MensajesAccionPedido.dinero(resumen.ventasCentavos),
        etiqueta: 'Ventas de hoy',
        detalle:
            '${resumen.entregados} entregados · ticket '
            '${ticket == null ? '—' : MensajesAccionPedido.dinero(ticket)}',
        color: AppColors.ok,
      ),
      _Dato(
        valor: minutos == null ? '—' : '$minutos min',
        etiqueta: 'Tiempo para confirmar',
        detalle: 'promedio de hoy',
        color: AppColors.texto,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= 900 ? 6 : (c.maxWidth >= 560 ? 3 : 2);
        const hueco = 8.0;
        final ancho = (c.maxWidth - hueco * (columnas - 1)) / columnas;
        return Wrap(
          spacing: hueco,
          runSpacing: hueco,
          children: [
            for (final t in tarjetas) SizedBox(width: ancho, child: t),
          ],
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.valor,
    required this.etiqueta,
    required this.detalle,
    required this.color,
  });

  final String valor;
  final String etiqueta;
  final String detalle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$etiqueta: $valor, $detalle',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bordeSutil),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valor,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.texto, fontSize: 12),
            ),
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.hint, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
