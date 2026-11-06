import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../providers/pedidos_provider.dart';

/// Lo de arriba de la lista, como en la maqueta:
///   - celular y tableta ([compacto]): título «Pedidos» con su globo de nuevos
///     y «En vivo», tres números en cajitas y las pestañas en una fila;
///   - PC: solo las pestañas, con Historial al final (los números van aparte).
/// Las insignias de Nuevos y Activos salen de lo ya cargado; «Por cobrar» es el
/// total del negocio si la consulta de suma respondió (si no, dice «cargados»).
/// Nada de esto lee por sí mismo.
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
    this.nuevos = 0,
    this.enVivo = true,
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

  /// Modo celular y tableta: título, tres números y botón de reloj. En PC va
  /// en false (los números van en su propia fila).
  final bool mostrarNumeros;

  /// Cuántos pedidos nuevos hay (el globo ámbar junto al título).
  final int nuevos;

  /// «● En vivo» o «● En pausa».
  final bool enVivo;

  bool get compacto => mostrarNumeros;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compacto) ...[
            _Encabezado(
              nuevos: nuevos,
              enVivo: enVivo,
              onHistorial: onHistorial,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Caja(conteoNuevos, 'Nuevos', AppColors.aviso),
                const SizedBox(width: 8),
                _Caja(conteoActivos, 'Activos', AppColors.azulTexto),
                const SizedBox(width: 8),
                _Caja(
                  MensajesAccionPedido.dinero(porCobrarCentavos),
                  porCobrarExacto ? 'Por cobrar' : 'Por cobrar (cargados)',
                  AppColors.aviso,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                // Wrap: si no caben en una fila, la última baja a otra línea
                // en vez de quedar cortada.
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in pestanas)
                      _Pestana(
                        texto: etiquetaPestana(p),
                        activa: pestana == p,
                        onTap: () => onPestana(p),
                      ),
                  ],
                ),
              ),
              if (!compacto)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 40),
                    foregroundColor: AppColors.azulTexto,
                    side: BorderSide(color: AppColors.bordeMedio),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onHistorial,
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Historial'),
                ),
            ],
          ),
          if (vencidos > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(compacto ? double.infinity : 44, 44),
                  foregroundColor: AppColors.azulTexto,
                  side: const BorderSide(color: AppColors.hint),
                  shape: const StadiumBorder(),
                ),
                onPressed: cancelandoVencidos ? null : onCancelarVencidos,
                child: Text(
                  cancelandoVencidos
                      ? 'Cancelando…'
                      : compacto
                      ? 'Cancelar $vencidos ${vencidos == 1 ? 'vencido' : 'vencidos'}'
                      : 'Cancelar vencidos ($vencidos)',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.nuevos,
    required this.enVivo,
    required this.onHistorial,
  });

  final int nuevos;
  final bool enVivo;
  final VoidCallback onHistorial;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Pedidos',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (nuevos > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.aviso,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$nuevos',
              style: const TextStyle(
                color: Color(0xFF201800),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const Spacer(),
        Flexible(
          child: Text(
            enVivo ? '● En vivo' : '● En pausa',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enVivo ? AppColors.ok : AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Historial',
          onPressed: onHistorial,
          icon: const Icon(Icons.history, color: AppColors.azulTexto),
        ),
      ],
    );
  }
}

/// Un número en su cajita (como `.met` de la maqueta).
class _Caja extends StatelessWidget {
  const _Caja(this.valor, this.etiqueta, this.color);

  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bordeMedio),
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
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              etiqueta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
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
          // Sin `alignment` en el Container: haría que la etiqueta ocupara todo
          // el ancho. Center con widthFactor mide justo lo que necesita.
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                texto,
                style: TextStyle(
                  color: activa ? Colors.white : AppColors.muted,
                  fontSize: 12,
                  fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
