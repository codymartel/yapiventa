import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/tipo_unidad.dart';
import '../providers/configuracion_negocio_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// PasoCatalogo — Paso 2 del wizard: "Categorías de productos" + "Unidades"
// ═════════════════════════════════════════════════════════════════════════
// Migración funcional de la sección de catálogo de ConfiguracionNegocioScreen.kt.
// Primera versión funcional — el diálogo rico de unidades (con fracciones
// rápidas, tipo entera/fraccionaria) se simplifica aquí a un diálogo con
// campos básicos; se puede enriquecer visualmente después.
// ═════════════════════════════════════════════════════════════════════════

class PasoCatalogo extends StatelessWidget {
  const PasoCatalogo({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Categorías de productos *',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¿Qué tipo de productos vendes?',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < p.categorias.length; i++)
              InputChip(
                label: Text(p.categorias[i]),
                backgroundColor: AppColors.card,
                labelStyle: TextStyle(color: AppColors.texto),
                onDeleted: () => p.eliminarCategoria(i),
                onPressed: () => _dialogoCategoria(context, p, index: i),
              ),
            IconButton(
              icon: Icon(Icons.add_circle, color: AppColors.blueLt),
              onPressed: () => _dialogoCategoria(context, p),
            ),
          ],
        ),
        if (p.faltaCategoria)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '⚠ Agrega al menos una categoría',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),

        const SizedBox(height: 28),
        Text(
          'Unidades de medida',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          'Personaliza cómo mides tus productos',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < p.unidadesMedida.length; i++)
              InputChip(
                backgroundColor: AppColors.card,
                label: Text(
                  '${p.unidadesMedida[i].nombre}'
                  '${p.unidadesMedida[i].tipo == TipoUnidad.fraccionaria ? " (fraccionaria)" : ""}',
                  style: TextStyle(color: AppColors.texto, fontSize: 13),
                ),
                onPressed: () => _dialogoUnidad(context, p, index: i),
                onDeleted: () => p.eliminarUnidad(i),
              ),
            IconButton(
              icon: Icon(Icons.add_circle, color: AppColors.blueLt),
              onPressed: () => _dialogoUnidad(context, p),
            ),
          ],
        ),
      ],
    );
  }

  void _dialogoCategoria(
    BuildContext context,
    ConfiguracionNegocioProvider p, {
    int? index,
  }) {
    final controller = TextEditingController(
      text: index != null ? p.categorias[index] : '',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text(
          index == null ? 'Nueva categoría' : 'Editar categoría',
          style: TextStyle(color: AppColors.texto),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.texto),
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              final texto = controller.text.trim();
              if (texto.isEmpty) return;
              if (index == null) {
                p.agregarCategoria(texto);
              } else {
                p.editarCategoria(index, texto);
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _dialogoUnidad(
    BuildContext context,
    ConfiguracionNegocioProvider p, {
    int? index,
  }) {
    final unidadActual = index != null ? p.unidadesMedida[index] : null;
    final nombreController = TextEditingController(
      text: unidadActual?.nombre ?? '',
    );
    final fraccionesController = TextEditingController(
      text: unidadActual?.fraccionesPermitidas.join(', ') ?? '',
    );
    var tipoSeleccionado = unidadActual?.tipo ?? TipoUnidad.fraccionaria;
    String? errorFracciones;

    return showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.superficie,
          title: Text(
            index == null ? 'Nueva unidad' : 'Editar unidad',
            style: TextStyle(color: AppColors.texto),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: TextStyle(color: AppColors.texto),
                decoration: const InputDecoration(
                  labelText: 'Nombre (ej: kg, litro, unidad)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<TipoUnidad>(
                      title: const Text(
                        'Fraccionaria',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: TipoUnidad.fraccionaria,
                      groupValue: tipoSeleccionado,
                      onChanged: (v) => setState(() => tipoSeleccionado = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<TipoUnidad>(
                      title: const Text(
                        'Entera',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: TipoUnidad.entera,
                      groupValue: tipoSeleccionado,
                      onChanged: (v) => setState(() => tipoSeleccionado = v!),
                    ),
                  ),
                ],
              ),
              if (tipoSeleccionado == TipoUnidad.fraccionaria) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: fraccionesController,
                  style: TextStyle(color: AppColors.texto),
                  onChanged: (_) {
                    if (errorFracciones != null) {
                      setState(() => errorFracciones = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Fracciones permitidas *',
                    hintText: 'Ej: 0.25, 0.5, 1',
                    errorText: errorFracciones,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sepáralas con comas.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              onPressed: () {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) return;
                final fracciones = fraccionesController.text
                    .split(',')
                    .map((fraccion) => fraccion.trim())
                    .where((fraccion) => fraccion.isNotEmpty)
                    .toList();
                if (tipoSeleccionado == TipoUnidad.fraccionaria &&
                    fracciones.isEmpty) {
                  setState(
                    () => errorFracciones =
                        'Agrega al menos una fracción permitida.',
                  );
                  return;
                }
                final unidad = UnidadInfo(
                  nombre: nombre,
                  tipo: tipoSeleccionado,
                  fraccionesPermitidas:
                      tipoSeleccionado == TipoUnidad.fraccionaria
                      ? fracciones
                      : const [],
                );
                if (index == null) {
                  p.agregarUnidad(unidad);
                } else {
                  p.editarUnidad(index, unidad);
                }
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nombreController.dispose();
      fraccionesController.dispose();
    });
  }
}
