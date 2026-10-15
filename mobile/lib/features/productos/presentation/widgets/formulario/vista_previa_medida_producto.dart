import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../application/services/entrada_numerica.dart';
import '../../providers/formulario_medida_controller.dart';

/// "Así lo ve tu cliente": las cantidades rápidas con su precio y un
/// ejemplo de pedido por monto. Los números vienen de VistaPreviaMedida
/// (enteros, redondeo hacia abajo a favor del cliente).
class VistaPreviaMedidaProducto extends StatelessWidget {
  const VistaPreviaMedidaProducto({super.key, required this.medida});

  final FormularioMedidaController medida;

  @override
  Widget build(BuildContext context) {
    final rapidas = medida.cantidadesRapidasConPrecio;
    final monto = medida.pedidoPorMontoEjemplo;
    final base = medida.unidadBaseNombre;
    final minimo = medida.minimoEfectivo;
    final incremento = medida.incrementoEfectivo;

    final hayAlgo = rapidas.isNotEmpty || monto != null;
    return Container(
      key: const Key('vista-previa-medida'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bordeSutil),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Así lo ve tu cliente',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (!hayAlgo)
            Text(
              'Escribe el precio para ver cómo queda.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          if (rapidas.isNotEmpty) ...[
            Text(
              'Cantidades rápidas',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final rapida in rapidas)
                  Chip(
                    key: Key('rapida-${rapida.cantidadBase}'),
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${rapida.etiqueta} · '
                      'S/ ${centavosATexto(rapida.precioCentavos)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
          if (monto != null) ...[
            const SizedBox(height: 6),
            Text(
              monto.esValido
                  ? 'Por soles: S/ ${centavosATexto(monto.montoCentavos)} → '
                        '${monto.etiqueta} (se cobra '
                        'S/ ${centavosATexto(monto.costoCentavos!)})'
                  : 'Por soles: S/ ${centavosATexto(monto.montoCentavos)} no '
                        'alcanza el mínimo',
              key: const Key('monto-ejemplo'),
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (hayAlgo && minimo > 0 && incremento > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Desde $minimo $base, de $incremento en $incremento $base',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
