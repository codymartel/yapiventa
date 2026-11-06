import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// La ayuda de Pedidos (el panel «¿Cómo funciona?» de los demás módulos):
/// el camino de un pedido, qué hace cada botón, para qué sirve cada pestaña y
/// unos consejos. Está escrita para alguien que nunca usó la pantalla.
class PedidosContextualPanel extends StatelessWidget {
  const PedidosContextualPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.sizeOf(context).width < 600;
    return DecoratedBox(
      key: const Key('pedidos-contextual-panel'),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Cómo funciona?',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: movil ? 17 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí llegan los pedidos de tu tienda web. Tú los atiendes, '
              'cambias su estado y escribes al cliente por WhatsApp.',
              style: _estiloTexto(movil),
            ),
            const _Grupo('El camino de un pedido'),
            _Fila(
              icono: Icons.fiber_new_outlined,
              titulo: 'Nuevo',
              texto: 'Acaba de llegar. Revísalo y confírmalo.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.check_circle_outline,
              titulo: 'Confirmado',
              texto:
                  'Lo aceptaste. En este paso se descuenta el stock de lo '
                  'que pidió.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.local_shipping_outlined,
              titulo: 'En camino / Listo para recoger',
              texto:
                  'En delivery sale a la calle; si es recojo, queda listo en '
                  'tu local.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.task_alt,
              titulo: 'Entregado',
              texto:
                  'Terminó. Te pregunta si ya cobraste y la venta suma a '
                  '«Ventas de hoy».',
              movil: movil,
            ),
            _Fila(
              icono: Icons.cancel_outlined,
              titulo: 'Cancelado',
              texto:
                  'Nunca se borra: queda en el Historial. Si ya estaba '
                  'confirmado, el stock vuelve.',
              movil: movil,
            ),
            const _Grupo('Qué hace cada botón'),
            _Fila(
              icono: Icons.touch_app_outlined,
              titulo: 'El botón grande de abajo',
              texto:
                  'Siempre es el siguiente paso: Confirmar, Enviar a '
                  'domicilio, Listo para recoger o Marcar entregado.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.inventory_2_outlined,
              titulo: 'Si falta stock',
              texto:
                  'Al confirmar te dice qué falta y cuánto hay. No cambia '
                  'nada hasta que repongas.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.payments_outlined,
              titulo: 'Marcar como cobrado',
              texto:
                  'Para el pago contra entrega o el que llega después. Lo '
                  'ves en «Por cobrar».',
              movil: movil,
            ),
            _Fila(
              icono: Icons.chat_outlined,
              titulo: 'WhatsApp',
              texto: 'Abre el chat con el cliente para avisarle de su pedido.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.undo,
              titulo: 'Cancelar',
              texto:
                  'Te pide confirmar. Si el cliente ya había pagado, queda '
                  'en «Reembolsos» hasta que le devuelvas el dinero.',
              movil: movil,
            ),
            const _Grupo('Las pestañas'),
            _Fila(
              icono: Icons.inbox_outlined,
              titulo: 'Nuevos y Activos',
              texto:
                  'Nuevos: por confirmar. Activos: confirmados, en camino o '
                  'listos para recoger.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.account_balance_wallet_outlined,
              titulo: 'Por cobrar',
              texto:
                  'Todo lo que falta cobrar, incluso lo ya entregado. Es el '
                  'dinero que te deben.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.currency_exchange_outlined,
              titulo: 'Reembolsos',
              texto: 'Cancelados que ya pagaron y falta devolverles el dinero.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.history,
              titulo: 'Historial',
              texto: 'Lo entregado y lo cancelado, ordenado por día.',
              movil: movil,
            ),
            const _Grupo('Buenos consejos'),
            _Fila(
              icono: Icons.timer_outlined,
              titulo: 'Vencidos',
              texto:
                  'Un pedido nuevo con más de 12 horas sin confirmar se '
                  'marca en rojo. Un botón te deja cancelarlos juntos.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.expand_more,
              titulo: 'De 10 en 10',
              texto:
                  'Se muestran los 10 más recientes. Toca «Ver más» para '
                  'los anteriores.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.pin_outlined,
              titulo: 'Los números de arriba',
              texto:
                  'Cuentan lo que ya está en pantalla. «Por cobrar» puede '
                  'decir «cargados» si solo suma lo que ves.',
              movil: movil,
            ),
            _Fila(
              icono: Icons.desktop_windows_outlined,
              titulo: 'En PC y TV',
              texto:
                  'En PC puedes buscar, marcar varios y confirmarlos juntos. '
                  'En una TV usa ▲ ▼ para moverte y OK para abrir.',
              movil: movil,
              ultimo: true,
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _estiloTexto(bool movil) => TextStyle(
  color: AppColors.texto.withValues(alpha: 0.72),
  fontSize: movil ? 12.5 : 12,
  height: 1.35,
);

class _Grupo extends StatelessWidget {
  const _Grupo(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        titulo.toUpperCase(),
        style: const TextStyle(
          color: AppColors.azulTexto,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.movil,
    this.ultimo = false,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final bool movil;
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
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: movil ? 14 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(texto, style: _estiloTexto(movil)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
