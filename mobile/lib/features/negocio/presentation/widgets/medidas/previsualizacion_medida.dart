import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../productos/domain/models/familia_unidad.dart';
import '../../../domain/models/catalogo_venta/formateador_presentacion.dart';
import '../../../domain/models/catalogo_venta/unidad_registrada.dart';

// ═════════════════════════════════════════════════════════════════════════
// Previsualización de medida
// ═════════════════════════════════════════════════════════════════════════

class PrevisualizacionMedida extends StatelessWidget {
  final String nombre;
  final FamiliaUnidad familia;
  final UnidadRegistrada unidadBase;
  final UnidadRegistrada unidadVisual;
  final int minimoBase;
  final int incrementoBase;
  final List<int> rapidasBase;
  final bool permiteCantidad;
  final bool permiteMonto;

  const PrevisualizacionMedida({
    super.key,
    required this.nombre,
    required this.familia,
    required this.unidadBase,
    required this.unidadVisual,
    required this.minimoBase,
    required this.incrementoBase,
    required this.rapidasBase,
    required this.permiteCantidad,
    required this.permiteMonto,
  });

  String _etiqueta(int base) => FormateadorPresentacion.formatear(
    FormateadorPresentacion.cantidadEnFamilia(familia, base),
    unidadVisual,
  );

  static const _margen = TextStyle(color: AppColors.muted, fontSize: 13);
  static const _negrita = TextStyle(
    color: AppColors.texto,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final minimoValido = minimoBase > 0;
    final incrementoValido = incrementoBase > 0;
    final secuencia = (minimoValido && incrementoValido)
        ? List.generate(
            4,
            (i) => '${minimoBase + i * incrementoBase} ${unidadBase.nombre}',
          ).join(', ')
        : null;

    return Container(
      key: const Key('previsualizacion-medida'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cómo lo verá el cliente',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(nombre, style: _negrita),
          const SizedBox(height: 4),
          Text(
            minimoValido
                ? 'Mínimo: $minimoBase ${unidadBase.nombre}'
                : 'Mínimo: —',
            style: _margen,
          ),
          Text(
            incrementoValido
                ? 'Incremento: $incrementoBase ${unidadBase.nombre}'
                : 'Incremento: —',
            style: _margen,
          ),
          Text(
            secuencia != null ? 'Secuencia: $secuencia...' : 'Secuencia: —',
            style: _margen,
          ),
          if (rapidasBase.isNotEmpty)
            Text(
              'Opciones rápidas: ${rapidasBase.map(_etiqueta).join(', ')}',
              style: _margen,
            ),
          Text(
            'Por cantidad: ${permiteCantidad ? 'Sí' : 'No'}',
            style: _margen,
          ),
          Text('Por soles: ${permiteMonto ? 'Sí' : 'No'}', style: _margen),
        ],
      ),
    );
  }
}
