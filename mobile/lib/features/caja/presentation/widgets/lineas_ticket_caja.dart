import 'package:flutter/material.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/carrito_caja.dart';
import '../../application/services/textos_dia_caja.dart';
import '../providers/venta_caja_provider.dart';

/// Las líneas de la venta: nombre, detalle, cantidad y su importe. Lo que se
/// cuenta por unidades trae − y + (con 0 se quita); lo que va por peso o
/// medida se quita con ✕ y se vuelve a agregar con otra cantidad. Los nombres
/// vienen de los productos del negocio y se muestran como texto plano.
class LineasTicketCaja extends StatelessWidget {
  const LineasTicketCaja({super.key, required this.provider});

  final VentaCajaProvider provider;

  @override
  Widget build(BuildContext context) {
    final lineas = provider.venta.lineas;
    if (lineas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Toca un producto de la lista para agregarlo a la venta.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lineas.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.dim),
          _Linea(linea: lineas[i], provider: provider),
        ],
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.linea, required this.provider});

  final LineaPedido linea;
  final VentaCajaProvider provider;

  String get _detalle {
    final partes = <String>[
      if (linea.etiqueta.isNotEmpty) linea.etiqueta,
      for (final e in linea.extras) '+ ${e.nombre}',
      linea.porMedida
          ? 'Cantidad: ${linea.cantidad}'
          : '${linea.cantidad} × ${TextosDiaCaja.numero(linea.precioCentavos)}',
    ];
    return partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final clave = CarritoCaja.claveDe(linea);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linea.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _detalle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (linea.porMedida)
            IconButton(
              tooltip: 'Quitar ${linea.nombre}',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
              onPressed: () => provider.quitar(clave),
            )
          else
            _Stepper(
              nombre: linea.nombre,
              cantidad: linea.cantidad,
              onCambiar: (n) => provider.cambiarCantidad(clave, n),
            ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52),
            child: Text(
              TextosDiaCaja.numero(linea.subtotalCentavos),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.azulTexto,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.nombre,
    required this.cantidad,
    required this.onCambiar,
  });

  final String nombre;
  final int cantidad;
  final ValueChanged<int> onCambiar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: cantidad <= 1 ? 'Quitar $nombre' : 'Quitar una unidad',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(
              cantidad <= 1 ? Icons.delete_outline : Icons.remove,
              size: 20,
              color: AppColors.azulTexto,
            ),
            onPressed: () => onCambiar(cantidad - 1),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24),
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Agregar una unidad',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.add, size: 20, color: AppColors.azulTexto),
            onPressed: () => onCambiar(cantidad + 1),
          ),
        ],
      ),
    );
  }
}
