import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../providers/formulario_modelos_controller.dart';

/// "¿Este producto viene en distintos colores, aromas, sabores…?". Si es Sí,
/// el vendedor le pone SU palabra a lo que cambia (el sistema solo sugiere
/// según el rubro). Si es No, el producto queda simple, como siempre.
class PreguntaModelosProducto extends StatelessWidget {
  const PreguntaModelosProducto({
    super.key,
    required this.modelos,
    required this.porMedida,
  });

  final FormularioModelosController modelos;
  final bool porMedida;

  @override
  Widget build(BuildContext context) {
    final sugerencia = modelos.sugerencia;
    final palabra = modelos.tituloCtrl.text.trim();
    return Container(
      key: const Key('pregunta-modelos'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeMedio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              children: [
                const TextSpan(text: '¿Este producto viene en distintos '),
                TextSpan(
                  text: sugerencia.ejemplo,
                  style: TextStyle(color: AppColors.muted),
                ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            key: const Key('segmento-modelos'),
            segments: const [
              ButtonSegment(value: true, label: Text('Sí')),
              ButtonSegment(value: false, label: Text('No')),
            ],
            selected: {modelos.usa},
            showSelectedIcon: false,
            onSelectionChanged: (seleccion) =>
                modelos.activar(seleccion.first, porMedida: porMedida),
          ),
          if (modelos.usa) ...[
            const SizedBox(height: 10),
            TextField(
              key: const Key('titulo-modelos'),
              controller: modelos.tituloCtrl,
              onChanged: (_) => modelos.trasCambioTexto(),
              style: TextStyle(color: AppColors.texto),
              decoration: const InputDecoration(
                labelText: '¿Cómo se llama lo que cambia? *',
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final sugerida in sugerencia.palabras)
                  ChoiceChip(
                    key: Key('sugerencia-$sugerida'),
                    label: Text(sugerida),
                    selected: palabra.toLowerCase() == sugerida.toLowerCase(),
                    onSelected: (_) => modelos.usarPalabra(sugerida),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Si lo que cambia necesita su propia foto, es un modelo. Si solo '
              'cambia cuánto hay (talla, tamaño), va dentro de cada modelo.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Sin variables: un solo precio y un solo stock.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
