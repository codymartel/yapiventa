import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'hoja_caja.dart';

/// Abre la ayuda de Caja en una hoja (celular y tableta) o un diálogo (PC).
Future<void> mostrarAyudaCaja(BuildContext context) {
  return mostrarHojaCaja<void>(
    context,
    builder: (c) => MarcoHojaCaja(
      titulo: '¿Cómo funciona?',
      textoCerrar: 'Cerrar',
      onCerrar: () => Navigator.of(c).pop(),
      elegir: const [ContenidoAyudaCaja()],
    ),
  );
}

/// La ayuda de Caja como panel (el «¿Cómo funciona?» de los demás módulos),
/// para mostrarla al costado en el tablero.
class CajaContextualPanel extends StatelessWidget {
  const CajaContextualPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('caja-contextual-panel'),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Cómo funciona?',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            ContenidoAyudaCaja(),
          ],
        ),
      ),
    );
  }
}

/// El texto de la ayuda de Caja: qué es, cómo vender, qué significa cada
/// número del día y cómo anotar un gasto. Escrita para alguien que nunca usó
/// la pantalla.
class ContenidoAyudaCaja extends StatelessWidget {
  const ContenidoAyudaCaja({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Caja registra todo lo que vende tu negocio: lo que cobras en tu '
          'local y los pedidos de tu tienda web cuando se entregan.',
          style: _texto,
        ),
        _Grupo('Vender en tu local'),
        _Fila(
          Icons.touch_app_outlined,
          'Toca un producto',
          'Elige la cantidad, el modelo o el peso y agrégalo a la venta.',
        ),
        _Fila(
          Icons.storefront_outlined,
          'Elige la entrega',
          'En tu local o para recoger se cobra y se entrega al momento. Con '
              'delivery pides los datos del cliente y la venta sigue en '
              'Pedidos hasta entregarla.',
        ),
        _Fila(
          Icons.payments_outlined,
          'Elige cómo te pagan y cobra',
          'Al cobrar, el stock baja solo. Si faltó stock o cambió un precio, '
              'te avisa y no cobra nada.',
        ),
        _Fila(
          Icons.undo,
          'Anular',
          'Tras cobrar tienes unos segundos para anular. La venta queda '
              'anulada (no se borra) y el stock vuelve.',
        ),
        _Grupo('Los números del día'),
        _Fila(
          Icons.trending_up,
          'Ventas de hoy',
          'Todo lo entregado hoy. Abajo lo ves separado: Local (tu '
              'mostrador) y Tienda web.',
        ),
        _Fila(
          Icons.account_balance_wallet_outlined,
          'Efectivo en caja',
          'Lo que te pagaron hoy en efectivo menos lo que gastaste en '
              'efectivo. Es lo que debería haber en tu cajón por lo de hoy.',
        ),
        _Fila(
          Icons.receipt_long_outlined,
          'Gastos',
          'La plata que salió hoy del negocio.',
        ),
        _Grupo('Anotar un gasto'),
        _Fila(
          Icons.north_east,
          'Botón «Gasto»',
          'Escribe cuánto, en qué (comida, pasaje, mercadería…) y de dónde '
              'salió la plata. Se resta de los números del día.',
        ),
        _Fila(
          Icons.block,
          'Si te equivocaste',
          'Toca «Anular» en el aviso. ¿Ya pasó? Toca «Gastos» en los '
              'números del día y luego «Corregir»: pones el monto bueno y '
              'el día se arregla solo. Nada se borra: el gasto malo queda '
              'tachado.',
          ultimo: true,
        ),
      ],
    );
  }
}

const _texto = TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45);

class _Grupo extends StatelessWidget {
  const _Grupo(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        titulo.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.icono, this.titulo, this.texto, {this.ultimo = false});

  final IconData icono;
  final String titulo;
  final String texto;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.blueLt.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icono, size: 17, color: AppColors.blueLt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(texto, style: _texto),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
