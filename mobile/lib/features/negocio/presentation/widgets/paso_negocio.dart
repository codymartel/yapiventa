import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/pais_telefono.dart';
import '../providers/configuracion_negocio_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// PasoNegocio — Paso 1 del wizard: "Datos del negocio"
// ═════════════════════════════════════════════════════════════════════════
// CONTENIDO: nombre, WhatsApp (prefijo + número), dirección y referencia, más
// las redes sociales opcionales.
//
// REGLA DE ESTE ARCHIVO: los controllers, las claves de los campos, los
// formatters y los callbacks que escriben en el provider son exactamente los
// mismos que antes. El rediseño solo cambia la presentación: una única
// superficie (nada de tarjeta dentro de tarjeta), labels separados del input,
// iconos dentro del input y el WhatsApp como un control compuesto en una fila.
// ═════════════════════════════════════════════════════════════════════════

class PasoNegocio extends StatefulWidget {
  const PasoNegocio({super.key});

  @override
  State<PasoNegocio> createState() => _PasoNegocioState();
}

enum _DisenoPaso {
  escritorio, // >= 720 px — redes sociales en dos columnas
  tablet, // 480–719 px — redes sociales en una columna
  movil, // < 480 px — una sola columna
}

class _PasoNegocioState extends State<PasoNegocio> {
  static const double _anchoEscritorio = 720;
  static const double _anchoTablet = 480;

  /// Ancho útil del formulario: cómodo de escanear sin estirar las líneas.
  static const double _anchoFormulario = 860;

  /// Alto de todos los controles de entrada del paso.
  static const double _altoCampo = 48;

  /// Ancho del selector de país dentro del control compuesto de WhatsApp.
  static const double _anchoSelectorPais = 180;

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
        final padding = ancho >= _anchoTablet ? 24.0 : 16.0;
        final diseno = ancho >= _anchoEscritorio
            ? _DisenoPaso.escritorio
            : (ancho >= _anchoTablet ? _DisenoPaso.tablet : _DisenoPaso.movil);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoFormulario),
            child: ListView(
              padding: EdgeInsets.fromLTRB(padding, 18, padding, 20),
              children: _contenido(p, diseno),
            ),
          ),
        );
      },
    );
  }

  // ── Estructura del contenido ──────────────────────────────────────────
  List<Widget> _contenido(ConfiguracionNegocioProvider p, _DisenoPaso diseno) {
    return [
      _encabezado(),
      const SizedBox(height: 18),
      _superficiePrincipal(p),
      const SizedBox(height: 20),
      _seccionOpcional(p, diseno),
    ];
  }

  Widget _encabezado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos del negocio',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Completa la información básica que verán tus clientes.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  /// Una sola superficie para los datos obligatorios. Los inputs van "hundidos"
  /// (fondo AppColors.superficie) sobre ella, y no hay ninguna tarjeta más
  /// dentro: el relieve lo da el contraste de superficie, no una caja extra.
  Widget _superficiePrincipal(ConfiguracionNegocioProvider p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bordeSutil),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _campoNombre(p),
          if (p.faltaNombre && p.nombreNegocio.isNotEmpty)
            _error('Mínimo 3 caracteres'),
          const SizedBox(height: 20),
          _bloqueWhatsApp(p),
          if (p.telefono.isNotEmpty && p.faltaTelefono)
            _error(
              'Faltan ${p.paisTelefono.digitosEsperados - p.telefono.length} dígito(s)',
            ),
          const SizedBox(height: 20),
          _campoDireccion(p),
          const SizedBox(height: 20),
          _campoReferencia(p),
        ],
      ),
    );
  }

  // ── Sección opcional (redes sociales) ─────────────────────────────────
  Widget _seccionOpcional(
    ConfiguracionNegocioProvider p,
    _DisenoPaso diseno,
  ) {
    final enPares = diseno == _DisenoPaso.escritorio;

    final facebook = _campoSocial(
      _facebookController,
      'Facebook',
      'https://facebook.com/...',
      Icons.public,
      (v) => p.linkFacebook = v,
    );
    final tiktok = _campoSocial(
      _tiktokController,
      'TikTok',
      'https://tiktok.com/...',
      Icons.music_note_outlined,
      (v) => p.linkTiktok = v,
    );
    final instagram = _campoSocial(
      _instagramController,
      'Instagram',
      'https://instagram.com/...',
      Icons.camera_alt_outlined,
      (v) => p.linkInstagram = v,
    );
    final youtube = _campoSocial(
      _youtubeController,
      'YouTube',
      'https://youtube.com/...',
      Icons.play_circle_outline,
      (v) => p.linkYoutube = v,
    );

    final grid = enPares
        ? Column(
            children: [
              _unPar(facebook, tiktok),
              const SizedBox(height: 16),
              _unPar(instagram, youtube),
            ],
          )
        : Column(
            children: [
              facebook,
              const SizedBox(height: 16),
              tiktok,
              const SizedBox(height: 16),
              instagram,
              const SizedBox(height: 16),
              youtube,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Redes sociales',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 15,
            height: 1.15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Opcional. Comparte tus redes para que te encuentren más rápido.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.bordeSutil),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              grid,
              if (p.linksMalos) ...[
                const SizedBox(height: 8),
                _error('Los links deben empezar con https://'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Campos ────────────────────────────────────────────────────────────
  Widget _campoNombre(ConfiguracionNegocioProvider p) {
    return _campoTexto(
      _nombreController,
      'Nombre del negocio *',
      'Ej: Carnes Don José',
      'Es el nombre que verán tus clientes en tu tienda.',
      Icons.storefront_outlined,
      (v) => p.nombreNegocio = v,
      key: const Key('campo_nombre'),
    );
  }

  /// WhatsApp como un único control compuesto: prefijo a la izquierda, número a
  /// la derecha, misma altura y separados por una hairline. En columnas muy
  /// estrechas el prefijo baja arriba, sin cambiar nada del contrato.
  Widget _bloqueWhatsApp(ConfiguracionNegocioProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('WhatsApp *'),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            // Uma única fila en cuanto hay ancho para el par [prefijo][número];
            // solo se apila en móvil muy estrecho.
            final apilado = constraints.maxWidth < 320;
            final prefijo = _selectorPais(p);
            final numero = _campoTelefono(p);
            if (apilado) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [prefijo, const SizedBox(height: 8), numero],
              );
            }
            // IntrinsicHeight: dentro de un ListView la altura del Row es
            // infinita, así que `stretch` no puede igualar las dos mitades por
            // sí solo. Con la altura intrínseca ambos controles comparten
            // exactamente la misma, incluso con el texto muy ampliado.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 150,
                      maxWidth: _anchoSelectorPais,
                    ),
                    child: prefijo,
                  ),
                  Container(width: 1, color: AppColors.bordeSutil),
                  Expanded(child: numero),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        const Text(
          'Aquí te escribirán tus clientes para hacer sus pedidos.',
          style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35),
        ),
      ],
    );
  }

  Widget _selectorPais(ConfiguracionNegocioProvider p) {
    return Container(
      constraints: const BoxConstraints(minHeight: _altoCampo),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bordeSutil),
      ),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<PaisTelefono>(
            key: const Key('selector_pais'),
            isExpanded: true,
            isDense: true,
            value: p.paisTelefono,
            dropdownColor: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            items: paisesLatam
                .map(
                  (pais) => DropdownMenuItem(
                    value: pais,
                    child: _OpcionPais(pais: pais),
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
        ),
      ),
    );
  }

  Widget _campoTelefono(ConfiguracionNegocioProvider p) {
    return TextField(
      key: const Key('campo_telefono'),
      controller: _telefonoController,
      onChanged: (v) => p.telefono = v,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(p.paisTelefono.digitosEsperados),
      ],
      style: const TextStyle(color: AppColors.texto, fontSize: 15, height: 1.2),
      decoration: _decoracion('${p.paisTelefono.digitosEsperados} dígitos'),
    );
  }

  Widget _campoDireccion(ConfiguracionNegocioProvider p) {
    return _campoTexto(
      _direccionController,
      'Dirección *',
      'Ej. Jr. Dos de Mayo 245, Huánuco',
      'La dirección donde entregas o recoges los pedidos.',
      Icons.place_outlined,
      (v) => p.direccion = v,
      key: const Key('campo_direccion'),
    );
  }

  Widget _campoReferencia(ConfiguracionNegocioProvider p) {
    return _campoTexto(
      _referenciaController,
      'Referencia *',
      'Ej. Frente al parque, puerta azul',
      'Una ayuda extra para que te encuentren más rápido.',
      Icons.near_me_outlined,
      (v) => p.referencia = v,
      key: const Key('campo_referencia'),
    );
  }

  Widget _campoSocial(
    TextEditingController controller,
    String label,
    String hint,
    IconData icono,
    ValueChanged<String> onChanged,
  ) {
    return _campoTexto(
      controller,
      label,
      hint,
      null,
      icono,
      onChanged,
    );
  }

  /// Campo de texto con label encima, icono dentro del input y una línea de
  /// ayuda debajo. El label ya no vive dentro del input: son dos niveles
  /// tipográficos distintos.
  Widget _campoTexto(
    TextEditingController controller,
    String label,
    String hint,
    String? ayuda,
    IconData icono,
    ValueChanged<String> onChanged, {
    Key? key,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          key: key,
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.texto, fontSize: 15, height: 1.2),
          decoration: _decoracion(hint, icono),
        ),
        if (ayuda != null) ...[
          const SizedBox(height: 6),
          Text(
            ayuda,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  // ── Helpers compartidos ───────────────────────────────────────────────
  Widget _unPar(Widget izquierda, Widget derecha) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: izquierda),
        const SizedBox(width: 16),
        Expanded(child: derecha),
      ],
    );
  }

  Widget _label(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _decoracion(String hint, [IconData? icono]) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.dim, fontSize: 15),
        filled: true,
        fillColor: AppColors.superficie,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        prefixIcon: icono == null
            ? null
            : Icon(icono, size: 18, color: AppColors.muted),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 20,
        ),
        constraints: const BoxConstraints(minHeight: _altoCampo),
        border: _borde(AppColors.bordeSutil),
        enabledBorder: _borde(AppColors.bordeSutil),
        focusedBorder: _borde(AppColors.blueLt, 1.5),
      );

  OutlineInputBorder _borde(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget _error(String msg) => Padding(
    padding: const EdgeInsets.only(top: 10, left: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 14, color: AppColors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// Bandera decorativa
// ═════════════════════════════════════════════════════════════════════════

/// Una opción del selector de país: [bandera] [prefijo] [nombre].
///
/// Se usa tanto para los ítems del menú como para el valor cerrado del
/// `DropdownButton`, así que el país seleccionado muestra su bandera sin
/// duplicar la composición en dos sitios. Solo presentación: el texto sigue
/// mostrando el prefijo y el nombre tal cual los define el modelo.
class _OpcionPais extends StatelessWidget {
  const _OpcionPais({required this.pais});

  final PaisTelefono pais;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Alto fijo: mantiene la bandera centrada respecto a la etiqueta aunque
        // la fuente cambie de tamaño.
        SizedBox(
          height: 18,
          child: Center(child: _BanderaPais(nombre: pais.nombre)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '${pais.prefijo} ${pais.nombre}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Bandera del país dibujada con franjas horizontales de color.
///
/// El proyecto no tiene assets de banderas y los emoji no se renderizan de
/// forma fiable en Flutter web, así que se compone con `ColoredBox`.
///
/// Cada país tiene SU PROPIA combinación de colores y proporciones, tomada de
/// su bandera real (número de franjas y altura de cada una), para que las 19
/// opciones del selector se distinguan de un vistazo. Es puramente decorativa:
/// el país siempre se nombra con su prefijo y su nombre, y el valor real del
/// selector no depende de esta ilustración.
class _BanderaPais extends StatelessWidget {
  const _BanderaPais({required this.nombre});

  final String nombre;

  static const double _ancho = 22;
  static const double _alto = 15;

  static const _rojo = Color(0xFFD7263D);
  static const _azul = Color(0xFF1F4E9C);
  static const _celeste = Color(0xFF74ACDF);
  static const _blanco = Color(0xFFF2F5FA);
  static const _verde = Color(0xFF1E7A46);
  static const _amarillo = Color(0xFFE0B323);
  static const _gris1 = Color(0xFF2A3A55);
  static const _gris2 = Color(0xFF22304A);
  static const _gris3 = Color(0xFF1C2840);

  /// Franjas de arriba abajo: (color, altura relativa).
  List<(Color, int)> get _franjas => switch (nombre) {
    'Argentina' => const [(_celeste, 1), (_blanco, 1), (_celeste, 1)],
    'Bolivia' => const [(_rojo, 1), (_amarillo, 1), (_verde, 1)],
    'Brasil' => const [(_verde, 3), (_amarillo, 2), (_azul, 3)],
    'Chile' => const [(_blanco, 1), (_rojo, 1), (_azul, 1)],
    'Colombia' => const [(_amarillo, 2), (_azul, 1), (_rojo, 1)],
    'Costa Rica' => const [
      (_azul, 1),
      (_blanco, 1),
      (_rojo, 2),
      (_blanco, 1),
      (_azul, 1),
    ],
    'Cuba' => const [(_azul, 1), (_blanco, 1), (_azul, 2), (_blanco, 1), (_azul, 1)],
    'Ecuador' => const [(_amarillo, 4), (_azul, 1), (_rojo, 1)],
    'El Salvador' => const [(_azul, 1), (_blanco, 1), (_azul, 1)],
    'Guatemala' => const [(_azul, 1), (_blanco, 1), (_azul, 1)],
    'Honduras' => const [(_azul, 1), (_blanco, 1), (_azul, 1)],
    'México' => const [(_verde, 1), (_blanco, 1), (_rojo, 1)],
    'Nicaragua' => const [(_azul, 1), (_blanco, 1), (_azul, 1)],
    // Panamá y República Dominicana son cuadradas: se leen como cuatro
    // cuadrantes de arriba abajo.
    'Panamá' => const [(_blanco, 1), (_azul, 1), (_rojo, 1), (_blanco, 1)],
    'Paraguay' => const [(_rojo, 1), (_blanco, 1), (_azul, 1)],
    'Perú' => const [(_rojo, 1), (_blanco, 1), (_rojo, 1)],
    'Uruguay' => const [(_blanco, 4), (_azul, 1), (_blanco, 4)],
    'Venezuela' => const [(_amarillo, 3), (_azul, 2), (_rojo, 1)],
    'República Dominicana' => const [
      (_azul, 1),
      (_rojo, 1),
      (_rojo, 1),
      (_azul, 1),
    ],
    _ => const [(_gris1, 1), (_gris2, 1), (_gris3, 1)],
  };

  /// Punto central con el color del escudo. Solo para los países que comparten
  /// la misma tricolor (azul-blanco-azul) y que, sin él, serían idénticos.
  Color? get _emblema => switch (nombre) {
    'El Salvador' => _amarillo,
    'Guatemala' => _celeste,
    'Honduras' => _azul,
    'Nicaragua' => _verde,
    'México' => _verde,
    'Brasil' => _azul,
    'Cuba' => _rojo,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final emblema = _emblema;
    return Container(
      width: _ancho,
      height: _alto,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.dim, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  for (final franja in _franjas)
                    Expanded(
                      flex: franja.$2,
                      child: ColoredBox(color: franja.$1),
                    ),
                ],
              ),
            ),
            if (emblema != null)
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: emblema,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
