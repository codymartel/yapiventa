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
// (nombre, WhatsApp, dirección, referencia y redes sociales).
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

enum _DisenoPaso {
  escritorio, // >= 720 px — filas con proporciones
  tablet, // 480–719 px — columnas apiladas
  movil, // < 480 px — columna única
}

class _PasoNegocioState extends State<PasoNegocio> {
  static const double _anchoEscritorio = 720;
  static const double _anchoTablet = 480;

  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _referenciaController = TextEditingController();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;

        if (ancho >= _anchoEscritorio) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                children: _contenido(p, _DisenoPaso.escritorio),
              ),
            ),
          );
        }

        if (ancho >= _anchoTablet) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: _contenido(p, _DisenoPaso.tablet),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: _contenido(p, _DisenoPaso.movil),
        );
      },
    );
  }

  // ── Estructura del contenido ──────────────────────────────────────────
  List<Widget> _contenido(ConfiguracionNegocioProvider p, _DisenoPaso diseno) {
    return [
      _encabezado(diseno),
      if (diseno == _DisenoPaso.escritorio)
        _tarjetaEscritorio(p)
      else
        _columnaSimple(p, diseno),
      _seccionOpcional(p, diseno),
    ];
  }

  Widget _encabezado(_DisenoPaso diseno) {
    final esEscritorio = diseno == _DisenoPaso.escritorio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos del negocio',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w600,
            fontSize: esEscritorio ? 20 : 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cuéntanos cómo se llama y cómo pueden contactarte',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: esEscritorio ? 13 : 12,
          ),
        ),
        SizedBox(height: esEscritorio ? 24 : 20),
      ],
    );
  }

  // ── Escritorio: tarjeta con filas proporcionales ──────────────────────
  Widget _tarjetaEscritorio(ConfiguracionNegocioProvider p) {
    return Card(
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
            // Fila 1: nombre 55% + WhatsApp 45%
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 55, child: _campoNombre(p)),
                const SizedBox(width: 16),
                Expanded(flex: 45, child: _bloqueWhatsApp(p)),
              ],
            ),
            if (p.faltaNombre && p.nombreNegocio.isNotEmpty)
              _error('Mínimo 3 caracteres'),
            if (p.telefono.isNotEmpty && p.faltaTelefono)
              _error(
                'Faltan ${p.paisTelefono.digitosEsperados - p.telefono.length} dígito(s)',
              ),
            const SizedBox(height: 20),
            // Fila 2: dirección ocupa todo el ancho
            _campoDireccion(p),
            const SizedBox(height: 20),
            // Fila 3: referencia ocupa todo el ancho
            _campoReferencia(p),
          ],
        ),
      ),
    );
  }

  // ── Móvil / tableta: columna única ────────────────────────────────────
  Widget _columnaSimple(ConfiguracionNegocioProvider p, _DisenoPaso diseno) {
    final espaciado = diseno == _DisenoPaso.tablet ? 16.0 : 14.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _campoNombre(p),
        if (p.faltaNombre && p.nombreNegocio.isNotEmpty)
          _error('Mínimo 3 caracteres'),
        SizedBox(height: espaciado),
        _bloqueWhatsApp(p),
        if (p.telefono.isNotEmpty && p.faltaTelefono)
          _error(
            'Faltan ${p.paisTelefono.digitosEsperados - p.telefono.length} dígito(s)',
          ),
        SizedBox(height: espaciado),
        _campoDireccion(p),
        SizedBox(height: espaciado),
        _campoReferencia(p),
      ],
    );
  }

  // ── Sección opcional (redes sociales) ─────────────────────────────────
  Widget _seccionOpcional(
    ConfiguracionNegocioProvider p,
    _DisenoPaso diseno,
  ) {
    final esEscritorio = diseno == _DisenoPaso.escritorio;

    final facebook = _campoSocial(
      _facebookController,
      'Facebook',
      'https://facebook.com/...',
      (v) => p.linkFacebook = v,
    );
    final tiktok = _campoSocial(
      _tiktokController,
      'TikTok',
      'https://tiktok.com/...',
      (v) => p.linkTiktok = v,
    );
    final instagram = _campoSocial(
      _instagramController,
      'Instagram',
      'https://instagram.com/...',
      (v) => p.linkInstagram = v,
    );
    final youtube = _campoSocial(
      _youtubeController,
      'YouTube',
      'https://youtube.com/...',
      (v) => p.linkYoutube = v,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: esEscritorio ? 28 : 24),
        Text(
          'Opcional',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: esEscritorio ? 13 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Redes sociales',
          style: TextStyle(
            color: AppColors.dim,
            fontSize: esEscritorio ? 12 : 11,
          ),
        ),
        const SizedBox(height: 16),
        if (esEscritorio)
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
                  _unPar(facebook, tiktok),
                  const SizedBox(height: 16),
                  _unPar(instagram, youtube),
                  if (p.linksMalos) ...[
                    const SizedBox(height: 8),
                    _error('Los links deben empezar con https://'),
                  ],
                ],
              ),
            ),
          )
        else ...[
          facebook,
          const SizedBox(height: 12),
          tiktok,
          const SizedBox(height: 12),
          instagram,
          const SizedBox(height: 12),
          youtube,
          if (p.linksMalos) ...[
            const SizedBox(height: 8),
            _error('Los links deben empezar con https://'),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Campos ────────────────────────────────────────────────────────────
  Widget _campoNombre(ConfiguracionNegocioProvider p) {
    return _campoTexto(
      _nombreController,
      'Nombre del negocio *',
      'Ej: Carnes Don José',
      (v) => p.nombreNegocio = v,
      key: const Key('campo_nombre'),
    );
  }

  Widget _bloqueWhatsApp(ConfiguracionNegocioProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WhatsApp *',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final apilado = constraints.maxWidth < 360;
            final tel = TextField(
              key: const Key('campo_telefono'),
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
            );
            final prefijo = DropdownButton<PaisTelefono>(
              key: const Key('selector_pais'),
              isExpanded: true,
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
            );
            if (apilado) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Align(alignment: Alignment.centerLeft, child: prefijo),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: tel),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: prefijo,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: tel),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _campoDireccion(ConfiguracionNegocioProvider p) {
    return _campoTexto(
      _direccionController,
      'Dirección *',
      'Ej. Jr. Dos de Mayo 245, Huánuco',
      (v) => p.direccion = v,
      key: const Key('campo_direccion'),
    );
  }

  Widget _campoReferencia(ConfiguracionNegocioProvider p) {
    return _campoTexto(
      _referenciaController,
      'Referencia *',
      'Ej. Frente al parque, puerta azul',
      (v) => p.referencia = v,
      key: const Key('campo_referencia'),
    );
  }

  Widget _campoSocial(
    TextEditingController controller,
    String label,
    String hint,
    ValueChanged<String> onChanged,
  ) {
    return _campoTexto(controller, label, hint, onChanged);
  }

  Widget _campoTexto(
    TextEditingController controller,
    String label,
    String hint,
    ValueChanged<String> onChanged, {
    Key? key,
  }) {
    return TextField(
      key: key,
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: AppColors.texto),
      decoration: _decoracion(label, hint),
    );
  }

  // ── Helpers compartidos ───────────────────────────────────────────────
  Widget _unPar(Widget izquierda, Widget derecha) {
    return Row(
      children: [
        Expanded(child: izquierda),
        const SizedBox(width: 16),
        Expanded(child: derecha),
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
    constraints: const BoxConstraints(minHeight: 48),
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