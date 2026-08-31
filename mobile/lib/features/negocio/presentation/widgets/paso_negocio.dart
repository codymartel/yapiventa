import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/pais_telefono.dart';
import '../providers/configuracion_negocio_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// PasoNegocio — Paso 1 del wizard: "Datos del negocio"
// ═════════════════════════════════════════════════════════════════════════
// Migración funcional de la primera sección de ConfiguracionNegocioScreen.kt
// (nombre, WhatsApp, dirección, referencia, RUC y redes sociales).
//
// Nota: esta es una primera versión funcional — prioriza que el flujo
// completo compile y funcione de punta a punta. El diseño rico de tu
// Kotlin (CardObligatoria con franja roja, CardOpcional colapsable,
// badges "Obligatorio"/"Opcional") se puede refinar visualmente después
// sin tocar la lógica de este archivo.
// ═════════════════════════════════════════════════════════════════════════

class PasoNegocio extends StatelessWidget {
  const PasoNegocio({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Datos del negocio',
            style: TextStyle(
                color: AppColors.texto, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),

        TextField(
          onChanged: (v) => p.nombreNegocio = v,
          style: TextStyle(color: AppColors.texto),
          decoration: _decoracion('Nombre del negocio *', 'Ej: Carnes Don José'),
        ),
        if (p.faltaNombre && p.nombreNegocio.isNotEmpty)
          _error('Mínimo 3 caracteres'),

        const SizedBox(height: 16),
        Text('WhatsApp *', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: [
            // NUEVO — selector de país en vez del "+51" fijo del Kotlin.
            DropdownButton<PaisTelefono>(
              value: p.paisTelefono,
              dropdownColor: AppColors.card,
              underline: const SizedBox(),
              style: TextStyle(color: AppColors.texto),
              items: paisesLatam
                  .map((pais) => DropdownMenuItem(
                        value: pais,
                        child: Text('${pais.prefijo} ${pais.nombre}'),
                      ))
                  .toList(),
              onChanged: (pais) {
                if (pais != null) p.paisTelefono = pais;
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => p.telefono = v,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.texto),
                decoration: _decoracion(
                    null, '${p.paisTelefono.digitosEsperados} dígitos'),
              ),
            ),
          ],
        ),
        if (p.telefono.isNotEmpty && p.faltaTelefono)
          _error('Faltan ${p.paisTelefono.digitosEsperados - p.telefono.length} dígito(s)'),

        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => p.direccion = v,
          style: TextStyle(color: AppColors.texto),
          decoration: _decoracion('Dirección *', 'Ej: Av. Perú 123'),
        ),

        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => p.referencia = v,
          style: TextStyle(color: AppColors.texto),
          decoration: _decoracion(
              'Referencia *', 'Ej: Frente a la plaza, al lado de farmacia'),
        ),

        const SizedBox(height: 24),
        Text('Opcional', style: TextStyle(color: AppColors.dim, fontSize: 11)),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => p.ruc = v,
          style: TextStyle(color: AppColors.texto),
          decoration: _decoracion('RUC / documento tributario', 'Opcional'),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => p.linkFacebook = v,
          style: TextStyle(color: AppColors.texto),
          decoration: _decoracion('Facebook', 'https://facebook.com/...'),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => p.linkTiktok = v,
          style: TextStyle(color: AppColors.texto),
          decoration: _decoracion('TikTok', 'https://tiktok.com/...'),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => p.linkInstagram = v,
          style: TextStyle(color: AppColors.texto),
          decoration: _decoracion('Instagram', 'https://instagram.com/...'),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => p.linkYoutube = v,
          style: TextStyle(color: AppColors.texto),
          decoration: _decoracion('YouTube', 'https://youtube.com/...'),
        ),
        if (p.linksMalos) _error('Los links deben empezar con https://'),
      ],
    );
  }

  InputDecoration _decoracion(String? label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.dim),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _error(String msg) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('⚠ $msg', style: TextStyle(color: AppColors.error, fontSize: 12)),
      );
}