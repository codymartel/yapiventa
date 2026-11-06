import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../providers/pedidos_provider.dart';

/// Lo de arriba de la lista: tres números (celular y tableta), las pestañas
/// con su insignia, el botón Historial y «Cancelar vencidos (N)». Las
/// insignias de Nuevos y Activos salen de lo ya cargado; «Por cobrar» es el
/// total del negocio si la consulta de suma respondió (si no, dice
/// «cargados»). Ninguno lee nada por sí mismo.
class FiltrosPedidos extends StatelessWidget {
  const FiltrosPedidos({
    super.key,
    required this.pestana,
    required this.pestanas,
    required this.etiquetaPestana,
    required this.conteoNuevos,
    required this.conteoActivos,
    required this.porCobrarCentavos,
    required this.porCobrarExacto,
    required this.vencidos,
    required this.cancelandoVencidos,
    required this.onPestana,
    required this.onHistorial,
    required this.onCancelarVencidos,
    this.mostrarNumeros = true,
  });

  final PestanaPedidos pestana;

  /// Las pestañas que se muestran, en orden (celular: 4; PC: 5).
  final List<PestanaPedidos> pestanas;

  /// El texto de cada pestaña, con su número si ya se puede mostrar.
  final String Function(PestanaPedidos) etiquetaPestana;
  final String conteoNuevos;
  final String conteoActivos;
  final int porCobrarCentavos;
  final bool porCobrarExacto;
  final int vencidos;
  final bool cancelandoVencidos;
  final ValueChanged<PestanaPedidos> onPestana;
  final VoidCallback onHistorial;
  final VoidCallback onCancelarVencidos;

  /// Los tres números de arriba (celular y tableta). En PC van en su propia fila.
  final bool mostrarNumeros;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mostrarNumeros)
            Row(
              children: [
                _Numero(conteoNuevos, 'Nuevos', AppColors.aviso),
                _Numero(conteoActivos, 'Activos', AppColors.azulTexto),
                _Numero(
                  MensajesAccionPedido.dinero(porCobrarCentavos),
                  porCobrarExacto ? 'Por cobrar' : 'Por cobrar (cargados)',
                  AppColors.aviso,
                ),
              ],
            ),
          if (mostrarNumeros) const SizedBox(height: 8),
          // Wrap: con letra grande, pantalla angosta o 5 pestañas, lo que no
          // cabe baja de línea en vez de salirse.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final p in pestanas)
                _Pestana(
                  texto: etiquetaPestana(p),
                  activa: pestana == p,
                  onTap: () => onPestana(p),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: onHistorial,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Historial'),
              ),
            ],
          ),
          if (vencidos > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size(44, 44),
                ),
                onPressed: cancelandoVencidos ? null : onCancelarVencidos,
                icon: const Icon(Icons.block, size: 18),
                label: Text(
                  cancelandoVencidos
                      ? 'Cancelando…'
                      : 'Cancelar vencidos ($vencidos)',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.valor, this.etiqueta, this.color);

  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      child: Material(
        color: activa ? AppColors.blue : AppColors.card,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              texto,
              style: TextStyle(
                color: activa ? Colors.white : AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
