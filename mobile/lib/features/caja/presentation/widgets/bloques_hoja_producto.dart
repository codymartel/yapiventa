import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/calculo_hoja_producto.dart';
import '../../application/services/mensajes_cobro_caja.dart';
import '../../application/services/textos_producto_caja.dart';

/// Arriba de la hoja: el nombre del producto, su precio y su stock, y
/// «Cambiar» para volver a la lista.
class EncabezadoHoja extends StatelessWidget {
  const EncabezadoHoja({
    super.key,
    required this.producto,
    required this.onCambiar,
  });

  final Producto producto;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final precio = TextosProductoCaja.precio(producto);
    final stock = producto.esCombo || producto.esStockInfinito
        ? ''
        : TextosProductoCaja.stock(producto);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                producto.nombre,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                TextosProductoCaja.precioYStock(precio, stock),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: AppColors.azulTexto,
          ),
          onPressed: onCambiar,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}

/// El recuadro de abajo: el resumen de lo elegido con su total, o lo que
/// falta (sin stock, no alcanza, falta elegir…) en texto y en ámbar.
class TotalHoja extends StatelessWidget {
  const TotalHoja({
    super.key,
    required this.resumen,
    required this.porMedida,
    required this.sinStock,
    required this.cantidadElegida,
    required this.falta,
  });

  final String? falta;
  final ResumenHojaProducto resumen;
  final bool porMedida;
  final bool sinStock;
  final int cantidadElegida;

  @override
  Widget build(BuildContext context) {
    String? aviso;
    if (sinStock) {
      aviso = 'No hay stock de esto.';
    } else if (resumen.noAlcanza) {
      aviso = 'Pides más de lo que hay.';
    } else if (resumen.linea == null) {
      aviso = porMedida && cantidadElegida == 0
          ? 'Elige cuánto se lleva.'
          : falta;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bordeSutil),
      ),
      child: aviso != null
          ? Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.aviso,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aviso,
                    style: const TextStyle(
                      color: AppColors.aviso,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    resumen.resumen.isEmpty
                        ? 'Total'
                        : (porMedida
                              ? '${resumen.resumen} salen'
                              : resumen.resumen),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  MensajesCobroCaja.dinero(resumen.subtotalCentavos),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    );
  }
}
