import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/textos_dia_caja.dart';
import '../providers/venta_caja_provider.dart';
import 'botones_caja.dart';
import 'datos_cliente_caja.dart';
import 'entrega_pago_caja.dart';
import 'hoja_caja.dart';
import 'lineas_ticket_caja.dart';

/// El pie de la venta: el desglose (solo si hay delivery o descuento), el
/// total y el único botón principal, «Cobrar». Apagado dice con TEXTO qué
/// falta. [enFila] lo pone en una sola línea cuando hay muy poco alto.
class PieTicketCaja extends StatelessWidget {
  const PieTicketCaja({
    super.key,
    required this.provider,
    required this.onCobrar,
    this.enFila = false,
  });

  final VentaCajaProvider provider;
  final VoidCallback onCobrar;
  final bool enFila;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final venta = p.venta;
    final total = TextosDiaCaja.plata(venta.totalCentavos);
    final boton = BotonPrincipalCaja(
      texto: p.cobrando
          ? 'Cobrando…'
          : p.carrito.vacio
          ? 'Agrega productos'
          : 'Cobrar $total',
      onTap: p.puedeCobrar ? onCobrar : null,
    );
    final falta = p.motivoNoCobrar;
    final aviso = falta == null
        ? null
        : Text(
            falta,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.aviso, fontSize: 12),
          );

    if (enFila) {
      // Muy poco alto: el aviso a la izquierda (2 líneas como mucho, nunca
      // empuja al botón) y «Cobrar» a la derecha.
      return Row(
        children: [
          Expanded(
            child: falta == null
                ? const SizedBox.shrink()
                : Tooltip(
                    message: falta,
                    child: Text(
                      falta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.aviso,
                        fontSize: 11,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 160, child: boton),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (venta.deliveryCentavos > 0)
          _Renglon('Delivery', TextosDiaCaja.numero(venta.deliveryCentavos)),
        if (venta.descuentoCentavos > 0)
          _Renglon(
            'Descuento por ${p.pago?.etiqueta ?? 'forma de pago'}',
            '− ${TextosDiaCaja.numero(venta.descuentoCentavos)}',
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Expanded(
              child: Text(
                'Total',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
            Text(
              total,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        boton,
        if (aviso != null) ...[const SizedBox(height: 6), aviso],
      ],
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon(this.titulo, this.valor);

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(color: AppColors.muted, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

/// La venta en un panel fijo al costado (tableta, celular de lado y PC). Lo
/// de arriba se desliza; el total y «Cobrar» nunca se van de la pantalla. Con
/// muy poco alto (teclado abierto de lado) el pie pasa a una sola línea.
class TicketCajaPanel extends StatelessWidget {
  const TicketCajaPanel({
    super.key,
    required this.provider,
    required this.rubro,
    required this.onCobrar,
  });

  final VentaCajaProvider provider;
  final String rubro;
  final VoidCallback onCobrar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) => LayoutBuilder(
        builder: (context, c) {
          final apretado = c.maxHeight < 300;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!apretado)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Venta',
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!provider.carrito.vacio)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            foregroundColor: AppColors.azulTexto,
                          ),
                          onPressed: provider.vaciar,
                          child: const Text('Vaciar'),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LineasTicketCaja(provider: provider),
                      const SizedBox(height: 12),
                      EntregaPagoCaja(provider: provider, rubro: rubro),
                      const SizedBox(height: 12),
                      DatosClienteCaja(provider: provider, rubro: rubro),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.dim),
              Padding(
                padding: EdgeInsets.fromLTRB(16, apretado ? 6 : 10, 16, 12),
                child: PieTicketCaja(
                  provider: provider,
                  onCobrar: onCobrar,
                  enFila: apretado,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// La venta en una hoja (celular vertical): se abre con «Ver venta». Devuelve
/// true si se tocó «Cobrar» (la hoja se cierra y el flujo cobra).
Future<bool?> mostrarTicketCaja(
  BuildContext context, {
  required VentaCajaProvider provider,
  required String rubro,
}) {
  return mostrarHojaCaja<bool>(
    context,
    builder: (c) => ListenableBuilder(
      listenable: provider,
      builder: (context, _) => MarcoHojaCaja(
        titulo: 'Venta',
        textoCerrar: 'Cerrar',
        onCerrar: () => Navigator.of(c).pop(false),
        elegir: [
          LineasTicketCaja(provider: provider),
          EntregaPagoCaja(provider: provider, rubro: rubro),
        ],
        escribirAlFinal: [DatosClienteCaja(provider: provider, rubro: rubro)],
        pie: PieTicketCaja(
          provider: provider,
          onCobrar: () => Navigator.of(c).pop(true),
        ),
        pieApretado: PieTicketCaja(
          provider: provider,
          onCobrar: () => Navigator.of(c).pop(true),
          enFila: true,
        ),
      ),
    ),
  );
}
