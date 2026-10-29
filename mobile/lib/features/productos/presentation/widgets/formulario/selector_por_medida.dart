import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../providers/formulario_medida_controller.dart';
import 'formato_entradas.dart';

/// El precio de un producto por medida y la cantidad que cubre: "S/ 3.00" por
/// "¼ kg". "Por" ofrece cantidades típicas y "Otra cantidad…" (con su propia
/// unidad). Debajo se muestra siempre cuánto sale el kg, para que un error
/// como S/ 12 por 1 g salte a la vista.
class SelectorPorMedida extends StatelessWidget {
  const SelectorPorMedida({
    super.key,
    required this.medida,
    this.conPrecio = true,
  });

  /// Valor del menú que significa "Otra cantidad…".
  static const _otra = -1;
  final FormularioMedidaController medida;

  /// false con modelos: cada modelo tiene su precio; acá solo se elige la
  /// cantidad que cubre.
  final bool conPrecio;

  @override
  Widget build(BuildContext context) {
    final familia = medida.familia;
    final equivalencia = medida.equivalencia;
    final esAlarma = medida.equivalenciaEsAlarma;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conPrecio) ...[
              Expanded(
                child: TextField(
                  key: const Key('precio-medida'),
                  controller: medida.precioCtrl,
                  onChanged: (_) => medida.trasCambioTexto(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [FormatoPrecio()],
                  style: TextStyle(color: AppColors.texto),
                  decoration: const InputDecoration(labelText: 'Precio S/ *'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey(
                  'por-${familia?.name ?? ''}-${medida.porBase}-'
                  '${medida.otraCantidad}',
                ),
                initialValue: familia == null
                    ? null
                    : (medida.otraCantidad ? _otra : medida.porBase),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: conPrecio ? 'Por *' : 'Cada precio es por *',
                ),
                hint: const Text('Elige qué mides'),
                items: [
                  for (final tipica in medida.opcionesPor)
                    DropdownMenuItem<int>(
                      value: tipica.base,
                      child: Text(tipica.etiqueta),
                    ),
                  const DropdownMenuItem<int>(
                    value: _otra,
                    child: Text('Otra cantidad…'),
                  ),
                ],
                onChanged: familia == null
                    ? null
                    : (valor) {
                        if (valor == null) return;
                        if (valor == _otra) {
                          medida.elegirOtraCantidad();
                        } else {
                          medida.cambiarPor(valor);
                        }
                      },
              ),
            ),
          ],
        ),
        if (medida.otraCantidad && familia != null) ...[
          const SizedBox(height: 10),
          _OtraCantidad(
            medida: medida,
            unidades: RegistroUnidades.unidadesDe(familia),
          ),
        ],
        if (equivalencia.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            esAlarma ? '⚠ $equivalencia. ¿Es correcto?' : equivalencia,
            key: const Key('equivalencia-medida'),
            style: TextStyle(
              color: esAlarma ? AppColors.aviso : AppColors.muted,
              fontSize: 13,
              fontWeight: esAlarma ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

/// Cantidad escrita + su unidad, cuando "Por" es "Otra cantidad…".
class _OtraCantidad extends StatelessWidget {
  const _OtraCantidad({required this.medida, required this.unidades});

  final FormularioMedidaController medida;
  final List<UnidadRegistrada> unidades;

  @override
  Widget build(BuildContext context) {
    final referencia = medida.referencia;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('referencia-medida'),
            controller: medida.referenciaCtrl,
            onChanged: (_) => medida.trasCambioTexto(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoCantidad()],
            style: TextStyle(color: AppColors.texto),
            decoration: InputDecoration(
              labelText: 'Cantidad que cubre el precio *',
              errorText: medida.referenciaCtrl.text.trim().isEmpty
                  ? null
                  : referencia?.error,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: DropdownButtonFormField<String>(
            key: ValueKey('unidad-otra-${medida.unidadOtra}'),
            initialValue: medida.unidadOtra.isEmpty ? null : medida.unidadOtra,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unidad'),
            items: [
              for (final unidad in unidades)
                DropdownMenuItem<String>(
                  value: unidad.nombre,
                  child: Text(unidad.nombre),
                ),
            ],
            onChanged: (valor) {
              if (valor != null) medida.cambiarUnidadOtra(valor);
            },
          ),
        ),
      ],
    );
  }
}
