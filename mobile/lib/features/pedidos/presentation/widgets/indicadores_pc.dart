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
    this.porCobrarCentavos,
    this.escala = 1,
  });

  final IndicadoresPedidos indicadores;
  final String conteoNuevos;
  final String conteoActivos;
  final ResumenVentasDia resumen;

  /// Lo que falta cobrar en TODO el negocio (consulta de suma). null = no se
  /// pudo: se usa lo cargado y la etiqueta dice «cargados».
  final int? porCobrarCentavos;

  /// 1 en PC; mayor en TV (letra de 20 px o más).
  final double escala;

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
        escala: escala,
      ),
      _Dato(
        valor: conteoActivos,
        etiqueta: 'Activos',
        detalle: '${indicadores.enCamino} en camino',
        color: AppColors.azulTexto,
        escala: escala,
      ),
      _Dato(
        valor: MensajesAccionPedido.dinero(
          porCobrarCentavos ?? indicadores.porCobrarCentavos,
        ),
        // «cargados» va en el detalle: en la etiqueta no cabía y se cortaba.
        etiqueta: 'Por cobrar',
        detalle: porCobrarCentavos != null
            ? 'de todo el negocio'
            : (indicadores.porCobrarPedidos == 1
                  ? 'de lo cargado · 1 pedido'
                  : 'de lo cargado · ${indicadores.porCobrarPedidos} pedidos'),
        color: AppColors.aviso,
        escala: escala,
      ),
      _Dato(
        valor: '${indicadores.vencidos}',
        etiqueta: 'Vencidos (+12 h)',
        detalle: 'sin confirmar',
        color: indicadores.vencidos > 0 ? AppColors.error : AppColors.muted,
        escala: escala,
      ),
      _Dato(
        valor: MensajesAccionPedido.dinero(resumen.ventasCentavos),
        etiqueta: 'Ventas de hoy',
        detalle:
            '${resumen.entregados} '
            '${resumen.entregados == 1 ? 'entregado' : 'entregados'} · ticket '
            '${ticket == null ? '—' : MensajesAccionPedido.dinero(ticket)}',
        color: AppColors.ok,
        escala: escala,
      ),
      _Dato(
        valor: minutos == null ? '—' : '$minutos min',
        etiqueta: 'Tiempo para confirmar',
        detalle: 'promedio de hoy',
        color: AppColors.texto,
        escala: escala,
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
    required this.escala,
  });

  final double escala;
  final String valor;
  final String etiqueta;
  final String detalle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$etiqueta: $valor, $detalle',
      child: Container(
        padding: EdgeInsets.all(12 * escala),
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
                  fontSize: 20 * escala,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.texto, fontSize: 12 * escala),
            ),
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.hint, fontSize: 11 * escala),
            ),
          ],
        ),
      ),
    );
  }
}
