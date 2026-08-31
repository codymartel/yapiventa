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
        Text('Categorías de productos *',
            style: TextStyle(
                color: AppColors.texto, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text('¿Qué tipo de productos vendes?',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
            child: Text('⚠ Agrega al menos una categoría',
                style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),

        const SizedBox(height: 28),
        Text('Unidades de medida',
            style: TextStyle(
                color: AppColors.texto, fontWeight: FontWeight.bold, fontSize: 16)),
        Text('Personaliza cómo mides tus productos',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < p.unidadesMedida.length; i++)
              Chip(
                backgroundColor: AppColors.card,
                label: Text(
                  '${p.unidadesMedida[i].nombre}'
                  '${p.unidadesMedida[i].tipo == TipoUnidad.fraccionaria ? " (fraccionaria)" : ""}',
                  style: TextStyle(color: AppColors.texto, fontSize: 13),
                ),
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

  void _dialogoCategoria(BuildContext context, ConfiguracionNegocioProvider p,
      {int? index}) {
    final controller =
        TextEditingController(text: index != null ? p.categorias[index] : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text(index == null ? 'Nueva categoría' : 'Editar categoría',
            style: TextStyle(color: AppColors.texto)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.texto),
          decoration: const InputDecoration(labelText: 'Nombre de la categoría'),
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

  void _dialogoUnidad(BuildContext context, ConfiguracionNegocioProvider p) {
    final nombreController = TextEditingController();
    var tipoSeleccionado = TipoUnidad.fraccionaria;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.superficie,
          title: Text('Nueva unidad', style: TextStyle(color: AppColors.texto)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: TextStyle(color: AppColors.texto),
                decoration:
                    const InputDecoration(labelText: 'Nombre (ej: kg, litro, unidad)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<TipoUnidad>(
                      title: const Text('Fraccionaria', style: TextStyle(fontSize: 12)),
                      value: TipoUnidad.fraccionaria,
                      groupValue: tipoSeleccionado,
                      onChanged: (v) => setState(() => tipoSeleccionado = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<TipoUnidad>(
                      title: const Text('Entera', style: TextStyle(fontSize: 12)),
                      value: TipoUnidad.entera,
                      groupValue: tipoSeleccionado,
                      onChanged: (v) => setState(() => tipoSeleccionado = v!),
                    ),
                  ),
                ],
              ),
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
                p.agregarUnidad(UnidadInfo(nombre: nombre, tipo: tipoSeleccionado));
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}