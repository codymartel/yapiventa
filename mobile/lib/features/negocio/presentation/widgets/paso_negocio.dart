import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class PasoNegocio extends StatefulWidget {
  const PasoNegocio({super.key});

  @override
  State<PasoNegocio> createState() => _PasoNegocioState();
}

class _PasoNegocioState extends State<PasoNegocio> {
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _referenciaController = TextEditingController();
  final _rucController = TextEditingController();
  final _facebookController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  bool _camposInicializados = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_camposInicializados) return;

    final p = context.read<ConfiguracionNegocioProvider>();
    _nombreController.text = p.nombreNegocio;
    _telefonoController.text = p.telefono;
    _direccionController.text = p.direccion;
    _referenciaController.text = p.referencia;
    _rucController.text = p.ruc;
    _facebookController.text = p.linkFacebook;
    _tiktokController.text = p.linkTiktok;
    _instagramController.text = p.linkInstagram;
    _youtubeController.text = p.linkYoutube;
    _camposInicializados = true;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _referenciaController.dispose();
    _rucController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  void _actualizarTelefonoVisible(String telefono) {
    _telefonoController.value = TextEditingValue(
      text: telefono,
      selection: TextSelection.collapsed(offset: telefono.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    final esDesktop = MediaQuery.sizeOf(context).width >= 600;

    final contenido = esDesktop
        ? _buildDesktop(context, p)
        : _buildMovil(context, p);

    if (esDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            children: contenido,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: contenido,
    );
  }

  // ── Desktop / Laptop ──────────────────────────────────────────────────
  List<Widget> _buildDesktop(
    BuildContext context,
    ConfiguracionNegocioProvider p,
  ) {
    return [
      Text(
        'Datos del negocio',
        style: TextStyle(
          color: AppColors.texto,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Cuéntanos cómo se llama y cómo pueden contactarte',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 24),

      // ── Tarjeta obligatoria ──
      Card(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _seccionLabel('Información principal'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nombreController,
                      onChanged: (v) => p.nombreNegocio = v,
                      style: TextStyle(color: AppColors.texto),
                      decoration: _decoracion(
                        'Nombre del negocio *',
                        'Ej: Carnes Don José',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _campoTelefono(p)),
                ],
              ),
              if (p.faltaNombre && p.nombreNegocio.isNotEmpty)
                _error('Mínimo 3 caracteres'),
              if (p.telefono.isNotEmpty && p.faltaTelefono)
                _error(
                  'Faltan ${p.paisTelefono.digitosEsperados - p.telefono.length} dígito(s)',
                ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _direccionController,
                      onChanged: (v) => p.direccion = v,
                      style: TextStyle(color: AppColors.texto),
                      decoration: _decoracion(
                        'Dirección *',
                        'Ej: Av. Perú 123',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _referenciaController,
                      onChanged: (v) => p.referencia = v,
                      style: TextStyle(color: AppColors.texto),
                      decoration: _decoracion(
                        'Referencia *',
                        'Ej: Frente a la plaza',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 28),

      // ── Sección opcional ──
      Text(
        'Opcional',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Redes sociales y datos fiscales',
        style: TextStyle(color: AppColors.dim, fontSize: 12),
      ),
      const SizedBox(height: 16),
      Card(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rucController,
                      onChanged: (v) => p.ruc = v,
                      style: TextStyle(color: AppColors.texto),
                      decoration: _decoracion(
                        'RUC / documento tributario',
                        'Opcional',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _facebookController,
                      onChanged: (v) => p.linkFacebook = v,
                      style: TextStyle(color: AppColors.texto),
                      decoration: _decoracion(
                        'Facebook',
                        'https://facebook.com/...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _tiktokController,
                      onChanged: (v) => p.linkTiktok = v,
                      style: TextStyle(color: AppColors.texto),
                      decoration: _decoracion(
                        'TikTok',
                        'https://tiktok.com/...',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _instagramController,
                      onChanged: (v) => p.linkInstagram = v,
                      style: TextStyle(color: AppColors.texto),
                      decoration: _decoracion(
                        'Instagram',
                        'https://instagram.com/...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _youtubeController,
                      onChanged: (v) => p.linkYoutube = v,
                      style: TextStyle(color: AppColors.texto),
                      decoration: _decoracion(
                        'YouTube',
                        'https://youtube.com/...',
                      ),
                    ),
                  ),
                ],
              ),
              if (p.linksMalos) ...[
                const SizedBox(height: 8),
                _error('Los links deben empezar con https://'),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  // ── Móvil ─────────────────────────────────────────────────────────────
  List<Widget> _buildMovil(
    BuildContext context,
    ConfiguracionNegocioProvider p,
  ) {
    return [
      Text(
        'Datos del negocio',
        style: TextStyle(
          color: AppColors.texto,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Cuéntanos cómo se llama y cómo pueden contactarte',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 20),

      TextField(
        controller: _nombreController,
        onChanged: (v) => p.nombreNegocio = v,
        style: TextStyle(color: AppColors.texto),
        decoration: _decoracion(
          'Nombre del negocio *',
          'Ej: Carnes Don José',
        ),
      ),
      if (p.faltaNombre && p.nombreNegocio.isNotEmpty)
        _error('Mínimo 3 caracteres'),

      const SizedBox(height: 16),
      _campoTelefono(p),
      if (p.telefono.isNotEmpty && p.faltaTelefono)
        _error(
          'Faltan ${p.paisTelefono.digitosEsperados - p.telefono.length} dígito(s)',
        ),

      const SizedBox(height: 16),
      TextField(
        controller: _direccionController,
        onChanged: (v) => p.direccion = v,
        style: TextStyle(color: AppColors.texto),
        decoration: _decoracion('Dirección *', 'Ej: Av. Perú 123'),
      ),

      const SizedBox(height: 16),
      TextField(
        controller: _referenciaController,
        onChanged: (v) => p.referencia = v,
        style: TextStyle(color: AppColors.texto),
        decoration: _decoracion(
          'Referencia *',
          'Ej: Frente a la plaza, al lado de farmacia',
        ),
      ),

      const SizedBox(height: 28),
      Text(
        'Opcional',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Redes sociales y datos fiscales',
        style: TextStyle(color: AppColors.dim, fontSize: 11),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _rucController,
        onChanged: (v) => p.ruc = v,
        style: TextStyle(color: AppColors.texto),
        decoration: _decoracion('RUC / documento tributario', 'Opcional'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _facebookController,
        onChanged: (v) => p.linkFacebook = v,
        style: TextStyle(color: AppColors.texto),
        decoration: _decoracion('Facebook', 'https://facebook.com/...'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _tiktokController,
        onChanged: (v) => p.linkTiktok = v,
        style: TextStyle(color: AppColors.texto),
        decoration: _decoracion('TikTok', 'https://tiktok.com/...'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _instagramController,
        onChanged: (v) => p.linkInstagram = v,
        style: TextStyle(color: AppColors.texto),
        decoration: _decoracion('Instagram', 'https://instagram.com/...'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _youtubeController,
        onChanged: (v) => p.linkYoutube = v,
        style: TextStyle(color: AppColors.texto),
        decoration: _decoracion('YouTube', 'https://youtube.com/...'),
      ),
      if (p.linksMalos) ...[
        const SizedBox(height: 8),
        _error('Los links deben empezar con https://'),
      ],
      const SizedBox(height: 24),
    ];
  }

  // ── Helpers compartidos ───────────────────────────────────────────────
  Widget _campoTelefono(ConfiguracionNegocioProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WhatsApp *',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            DropdownButton<PaisTelefono>(
              value: p.paisTelefono,
              dropdownColor: AppColors.card,
              underline: const SizedBox(),
              style: TextStyle(color: AppColors.texto),
              items: paisesLatam
                  .map(
                    (pais) => DropdownMenuItem(
                      value: pais,
                      child: Text('${pais.prefijo} ${pais.nombre}'),
                    ),
                  )
                  .toList(),
              onChanged: (pais) {
                if (pais != null) {
                  p.paisTelefono = pais;
                  _actualizarTelefonoVisible(p.telefono);
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _telefonoController,
                onChanged: (v) => p.telefono = v,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                    p.paisTelefono.digitosEsperados,
                  ),
                ],
                style: TextStyle(color: AppColors.texto),
                decoration: _decoracion(
                  null,
                  '${p.paisTelefono.digitosEsperados} dígitos',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _seccionLabel(String texto) {
    return Text(
      texto,
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _decoracion(String? label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.dim),
    labelStyle: TextStyle(color: AppColors.muted),
    filled: true,
    fillColor: AppColors.superficie,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.blueLt, width: 1.5),
    ),
  );

  Widget _error(String msg) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      '⚠ $msg',
      style: TextStyle(color: AppColors.error, fontSize: 12),
    ),
  );
}
