import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/models/zona_delivery.dart';
import '../../domain/models/horario_dia.dart';
import '../providers/configuracion_negocio_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// PasoLogistica — Paso 3 del wizard: "Delivery" + "Horario de atención"
// ═════════════════════════════════════════════════════════════════════════

class PasoLogistica extends StatelessWidget {
  const PasoLogistica({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('¿Ofreces delivery?',
                      style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w600)),
                  Switch(
                    value: p.tieneDelivery,
                    onChanged: (v) => p.tieneDelivery = v,
                  ),
                ],
              ),
              if (p.tieneDelivery) ...[
                const SizedBox(height: 12),
                Text('Zonas de delivery *',
                    style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (var i = 0; i < p.zonasDelivery.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    tileColor: AppColors.card,
                    title: Text(p.zonasDelivery[i].zona,
                        style: TextStyle(color: AppColors.texto)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('S/ ${p.zonasDelivery[i].costo}',
                            style: TextStyle(color: AppColors.blueLt)),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                          onPressed: () => p.eliminarZona(i),
                        ),
                      ],
                    ),
                    onTap: () => _dialogoZona(context, p, index: i),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _dialogoZona(context, p),
                  icon: Icon(Icons.add, color: AppColors.blueLt, size: 16),
                  label: Text('Agregar zona de delivery',
                      style: TextStyle(color: AppColors.blueLt)),
                ),
                if (p.faltaZonas)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('⚠ Agrega al menos una zona de delivery',
                        style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text('Horario de atención (opcional)',
            style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        for (var i = 0; i < p.horarios.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            tileColor: AppColors.card,
            title: Text(p.horarios[i].dia, style: TextStyle(color: AppColors.texto)),
            subtitle: Text(
              p.horarios[i].activo
                  ? '${p.horarios[i].apertura} – ${p.horarios[i].cierre}'
                  : 'Cerrado',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              onPressed: () => p.eliminarHorario(i),
            ),
            onTap: () => _dialogoHorario(context, p, index: i),
          ),
        OutlinedButton.icon(
          onPressed: () => _dialogoHorario(context, p),
          icon: Icon(Icons.add, color: AppColors.muted, size: 16),
          label: Text('Agregar horario', style: TextStyle(color: AppColors.muted)),
        ),
      ],
    );
  }

  void _dialogoZona(BuildContext context, ConfiguracionNegocioProvider p, {int? index}) {
    final zonaController =
        TextEditingController(text: index != null ? p.zonasDelivery[index].zona : '');
    final costoController =
        TextEditingController(text: index != null ? p.zonasDelivery[index].costo : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text(index == null ? 'Nueva zona' : 'Editar zona',
            style: TextStyle(color: AppColors.texto)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: zonaController,
              style: TextStyle(color: AppColors.texto),
              decoration: const InputDecoration(labelText: 'Zona (Ej: Centro)'),
            ),
            TextField(
              controller: costoController,
              style: TextStyle(color: AppColors.texto),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Costo S/'),
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
              if (zonaController.text.trim().isEmpty ||
                  costoController.text.trim().isEmpty) {
                return;
              }
              final zona = ZonaDelivery(
                zona: zonaController.text.trim(),
                costo: costoController.text.trim(),
              );
              if (index == null) {
                p.agregarZona(zona);
              } else {
                p.editarZona(index, zona);
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _dialogoHorario(BuildContext context, ConfiguracionNegocioProvider p, {int? index}) {
    var dia = index != null ? p.horarios[index].dia : diasSemana[0];
    var apertura = index != null ? p.horarios[index].apertura : '08:00';
    var cierre = index != null ? p.horarios[index].cierre : '18:00';
    var activo = index != null ? p.horarios[index].activo : true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.superficie,
          title: Text(index == null ? 'Agregar horario' : 'Editar horario',
              style: TextStyle(color: AppColors.texto)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: dia,
                dropdownColor: AppColors.card,
                isExpanded: true,
                style: TextStyle(color: AppColors.texto),
                items: diasSemana
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => dia = v!),
              ),
              SwitchListTile(
                title: const Text('Abierto este día', style: TextStyle(fontSize: 13)),
                value: activo,
                onChanged: (v) => setState(() => activo = v),
              ),
              if (activo) ...[
                TextField(
                  decoration: const InputDecoration(labelText: 'Apertura (HH:mm)'),
                  controller: TextEditingController(text: apertura),
                  onChanged: (v) => apertura = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Cierre (HH:mm)'),
                  controller: TextEditingController(text: cierre),
                  onChanged: (v) => cierre = v,
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
                final horario = HorarioDia(
                  dia: dia,
                  apertura: apertura,
                  cierre: cierre,
                  activo: activo,
                );
                if (index == null) {
                  p.agregarHorario(horario);
                } else {
                  p.editarHorario(index, horario);
                }
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