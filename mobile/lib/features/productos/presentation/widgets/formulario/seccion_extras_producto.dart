import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../application/services/entrada_numerica.dart';
import '../../../domain/models/estructura_producto.dart';
import '../../providers/formulario_extras_controller.dart';
import 'formato_entradas.dart';

/// Desde este ancho el editor de extras es un diálogo centrado; por debajo,
/// una hoja que sube desde abajo (mismo patrón de las demás ventanas).
const double anchoEditorEnDialogo = 900;

/// «➕ Extras · 2 extras ›»: una sola línea en el formulario. Al tocarla se
/// abre el editor. Los extras se guardan al dar «Guardar producto».
class SeccionExtrasProducto extends StatelessWidget {
  const SeccionExtrasProducto({super.key, required this.extras});

  final FormularioExtrasController extras;

  @override
  Widget build(BuildContext context) {
    final cantidad = extras.cantidad;
    final resumen = cantidad == 0
        ? 'opcional'
        : (cantidad == 1 ? '1 extra' : '$cantidad extras');
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('linea-extras'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => abrirEditorExtras(context, extras),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.bordeMedio),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, size: 20),
              const SizedBox(width: 10),
              Text(
                'Extras',
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '$resumen ›',
                key: const Key('resumen-extras'),
                style: TextStyle(color: AppColors.azulTexto, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre el editor: hoja desde abajo en celular, diálogo centrado en PC.
/// «Cancelar» deja los extras como estaban al abrir; «Listo» solo cierra.
Future<void> abrirEditorExtras(
  BuildContext context,
  FormularioExtrasController extras,
) {
  final copia = extras.copiar();
  final ancho = MediaQuery.sizeOf(context).width;

  void cancelar(BuildContext contexto) {
    extras.restaurar(copia);
    Navigator.of(contexto).pop();
  }

  if (ancho >= anchoEditorEnDialogo) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.superficie,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _EditorExtras(
              extras: extras,
              onListo: () => Navigator.of(dialogContext).pop(),
              onCancelar: () => cancelar(dialogContext),
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.dim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _EditorExtras(
              extras: extras,
              onListo: () => Navigator.of(sheetContext).pop(),
              onCancelar: () => cancelar(sheetContext),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EditorExtras extends StatelessWidget {
  const _EditorExtras({
    required this.extras,
    required this.onListo,
    required this.onCancelar,
  });

  final FormularioExtrasController extras;
  final VoidCallback onListo;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: extras,
      builder: (context, _) {
        final falta = extras.queFalta();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Extras',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(
                    text: '¿El cliente puede agregar algo extra? ',
                  ),
                  TextSpan(
                    text: 'con ají, + papas, bordado…',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: const Key('segmento-extras'),
              segments: const [
                ButtonSegment(value: true, label: Text('Sí')),
                ButtonSegment(value: false, label: Text('No')),
              ],
              selected: {extras.usa},
              showSelectedIcon: false,
              onSelectionChanged: (seleccion) =>
                  extras.activar(seleccion.first),
            ),
            if (!extras.usa)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Sin extras: se vende tal cual.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              )
            else ...[
              const SizedBox(height: 6),
              Text(
                'Toca uno para agregarlo, o escribe el tuyo.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              _Sugeridos(extras: extras),
              for (final fila in extras.filas)
                _FilaExtra(key: ValueKey(fila.id), extras: extras, fila: fila),
              if (extras.puedeAgregar)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('agregar-extra'),
                    onPressed: extras.agregar,
                    child: Text(
                      '+ Agregar otro extra · ${extras.filas.length} de '
                      '${ExtraProducto.maximo}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
            if (falta != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  falta,
                  key: const Key('falta-extras'),
                  style: TextStyle(
                    color: AppColors.aviso,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('cancelar-extras'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: onCancelar,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('listo-extras'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onListo,
                    child: const Text('Listo'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Los extras de ejemplo del rubro que aún no se agregaron.
class _Sugeridos extends StatelessWidget {
  const _Sugeridos({required this.extras});

  final FormularioExtrasController extras;

  @override
  Widget build(BuildContext context) {
    final pendientes = extras.sugerenciasPendientes;
    if (pendientes.isEmpty || !extras.puedeAgregar) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final sugerido in pendientes)
            ActionChip(
              key: Key('sugerido-${sugerido.nombre}'),
              label: Text(
                sugerido.precioCentavos > 0
                    ? '+ ${sugerido.nombre} S/ ${centavosATexto(sugerido.precioCentavos)}'
                    : '+ ${sugerido.nombre}',
              ),
              onPressed: () => extras.agregarSugerido(sugerido),
            ),
        ],
      ),
    );
  }
}

class _FilaExtra extends StatelessWidget {
  const _FilaExtra({super.key, required this.extras, required this.fila});

  final FormularioExtrasController extras;
  final ExtraEditable fila;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: Key('extra-nombre-${fila.id}'),
              controller: fila.nombreCtrl,
              onChanged: (_) => extras.trasCambioTexto(),
              style: TextStyle(color: AppColors.texto),
              decoration: const InputDecoration(
                labelText: 'Extra',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: TextField(
              key: Key('extra-precio-${fila.id}'),
              controller: fila.precioCtrl,
              onChanged: (_) => extras.trasCambioTexto(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [FormatoPrecio()],
              style: TextStyle(color: AppColors.texto),
              decoration: const InputDecoration(
                labelText: 'Precio S/',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            key: Key('quitar-extra-${fila.id}'),
            tooltip: 'Quitar extra',
            onPressed: () => extras.quitar(fila.id),
            icon: Icon(Icons.close, size: 18, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
