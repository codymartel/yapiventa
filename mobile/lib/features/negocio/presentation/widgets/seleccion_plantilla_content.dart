import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/plantilla_web.dart';

/// Contenido de la selección de plantilla web.
///
/// Es puramente de presentación: recibe el estado y dispara callbacks.
/// No crea providers, no consulta repositorios ni abre URLs. La pantalla
/// que lo embeba (hoy [SeleccionPlantillaScreen], mañana el dashboard)
/// conserva el [Scaffold], la navegación, la apertura de la tienda y la
/// coordinación con el provider.
///
/// Responsive con el ancho local vía [LayoutBuilder]: 1 columna hasta
/// 599 px, 2 hasta 999 px y 4 desde 1000 px (contenido limitado a 980 px).
class SeleccionPlantillaContent extends StatelessWidget {
  static const fondo = Color(0xFF070C18);

  static const _marinoCard = Color(0xFF0A1B2E);
  static const _azulAcento = Color(0xFF1E88E5);
  static const _marinoBorde = Color(0xFF1A3050);
  static const _blancoPuro = Color(0xFFFFFFFF);
  static const _grisTenue = Color(0xFF8FA8C0);

  static const List<Plantilla> _plantillas = [
    Plantilla(
      id: PlantillaWeb.neon,
      nombre: 'Neon',
      rubroSugerido: 'Tech / Electrónica',
      descripcion:
          'Fondo oscuro con acentos verde-cian. Ideal para productos tecnológicos.',
    ),
    Plantilla(
      id: PlantillaWeb.cristal,
      nombre: 'Cristal',
      rubroSugerido: 'Farmacia / Ferretería',
      descripcion:
          'Fondo claro, mucho espacio en blanco y sombras suaves. Sensación limpia y confiable.',
    ),
    Plantilla(
      id: PlantillaWeb.sabroso,
      nombre: 'Sabroso',
      rubroSugerido: 'Restaurante',
      descripcion:
          'Fondo crema cálido con naranja quemado. La comida es la protagonista.',
    ),
    Plantilla(
      id: PlantillaWeb.galeria,
      nombre: 'Galería',
      rubroSugerido: 'Ropa / Moda',
      descripcion:
          'Morado pastel, tipografía serif y lookbook de fotos. Con carrito en la tienda.',
    ),
  ];

  final String rubro;
  final PlantillaWeb? plantillaSeleccionada;
  final PlantillaWeb? plantillaGuardada;
  final bool cargando;
  final bool cargado;
  final bool guardando;
  final bool cambiosPendientes;
  final String? error;
  final ValueChanged<PlantillaWeb> onSeleccionarPlantilla;
  final VoidCallback onFinalizar;
  final VoidCallback onVerTienda;
  final VoidCallback onIrDashboard;

  const SeleccionPlantillaContent({
    super.key,
    required this.rubro,
    required this.plantillaSeleccionada,
    required this.plantillaGuardada,
    required this.cargando,
    required this.cargado,
    required this.guardando,
    required this.cambiosPendientes,
    required this.error,
    required this.onSeleccionarPlantilla,
    required this.onFinalizar,
    required this.onVerTienda,
    required this.onIrDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoDisponible = constraints.maxWidth;
        final columnas = anchoDisponible < 600
            ? 1
            : anchoDisponible < 1000
            ? 2
            : 4;

        final anchoMaximoContenido = anchoDisponible > 1000
            ? 980.0
            : anchoDisponible;
        const separacion = 16.0;
        final anchoTarjeta =
            (anchoMaximoContenido - 48 - separacion * (columnas - 1)) /
            columnas;
        final botonAncho = (anchoMaximoContenido - 48 - 12) / 2;
        final apilarBotones = anchoDisponible < 560;

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: anchoMaximoContenido),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),

                    const Text(
                      'PLANTILLA',
                      style: TextStyle(
                        color: _azulAcento,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Elige el estilo\nde tu tienda',
                      style: TextStyle(
                        color: _blancoPuro,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      rubro.isEmpty
                          ? 'Se aplicará automáticamente a tu catálogo.'
                          : 'Se verá con tus productos de $rubro.',
                      style: const TextStyle(color: _grisTenue, fontSize: 14),
                    ),

                    const SizedBox(height: 40),

                    if (cargando && !cargado)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 64),
                        child: const Center(
                          child: CircularProgressIndicator(
                            key: Key('plantilla-cargando'),
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    else
                      KeyedSubtree(
                        key: const Key('plantillas-wrap'),
                        child: Wrap(
                          spacing: separacion,
                          runSpacing: separacion,
                          children: [
                            for (final plantilla in _plantillas)
                              SizedBox(
                                width: anchoTarjeta,
                                child: _PlantillaCard(
                                  plantilla: plantilla,
                                  seleccionada:
                                      plantillaSeleccionada == plantilla.id,
                                  onTap: () =>
                                      onSeleccionarPlantilla(plantilla.id),
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('finalizar-plantilla'),
                        onPressed:
                            !cargado ||
                                plantillaSeleccionada == null ||
                                guardando
                            ? null
                            : onFinalizar,
                        icon: guardando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                        label: Text(guardando ? 'Guardando...' : 'Finalizar'),
                      ),
                    ),

                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Botones: Ver tienda web + Ir al dashboard ──
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: apilarBotones ? double.infinity : botonAncho,
                          child: OutlinedButton.icon(
                            key: const Key('ver-tienda-plantilla'),
                            onPressed: onVerTienda,
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Ver tienda web'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _azulAcento,
                              side: const BorderSide(
                                color: _azulAcento,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          width: apilarBotones ? double.infinity : botonAncho,
                          child: ElevatedButton.icon(
                            key: const Key('ir-dashboard-plantilla'),
                            onPressed:
                                cambiosPendientes ||
                                    plantillaGuardada == null ||
                                    guardando
                                ? null
                                : onIrDashboard,
                            icon: const Icon(Icons.home_outlined, size: 18),
                            label: const Text('Ir al dashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _azulAcento,
                              foregroundColor: _blancoPuro,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 32, top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _marinoCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _marinoBorde, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: _azulAcento,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Puedes cambiar tu plantilla cuando quieras',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _grisTenue,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modelo simple de plantilla. El `id` coincide 1:1 con la carpeta del
/// molde en web/public/moldes/{id}/.
class Plantilla {
  final PlantillaWeb id;
  final String nombre;
  final String rubroSugerido;
  final String descripcion;

  const Plantilla({
    required this.id,
    required this.nombre,
    required this.rubroSugerido,
    required this.descripcion,
  });
}

// ═════════════════════════════════════════════════════════════════════════
// _PlantillaCard
// ═════════════════════════════════════════════════════════════════════════
// Card de cada plantilla con una miniatura estilizada del molde (un
// degradado que evoca la paleta de cada plantilla web) y hover en
// web/desktop, igual que _RubroCard de SeleccionNegocioContent.
// ═════════════════════════════════════════════════════════════════════════

class _PlantillaCard extends StatefulWidget {
  final Plantilla plantilla;
  final bool seleccionada;
  final VoidCallback onTap;

  const _PlantillaCard({
    required this.plantilla,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  State<_PlantillaCard> createState() => _PlantillaCardState();
}

class _PlantillaCardState extends State<_PlantillaCard> {
  static const Color blancoPuro = Color(0xFFFFFFFF);
  static const Color azulAcento = Color(0xFF1E88E5);
  static const Color marinoCard = Color(0xFF0A1B2E);
  static const Color grisTenue = Color(0xFF8FA8C0);

  static const Map<PlantillaWeb, List<Color>> _paletas = {
    PlantillaWeb.neon: [Color(0xFF00FF88), Color(0xFF0A0A0F)],
    PlantillaWeb.cristal: [Color(0xFF8ED1B8), Color(0xFFF6F7F9)],
    PlantillaWeb.sabroso: [Color(0xFFE65100), Color(0xFFFAF6F0)],
    PlantillaWeb.galeria: [Color(0xFF6C45A8), Color(0xFFF4F1FB)],
  };

  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final paleta =
        _paletas[widget.plantilla.id] ??
        const [Color(0xFF1E88E5), Color(0xFF0A1B2E)];
    final destacada = widget.seleccionada || _hover || _focused;

    return Semantics(
      key: Key('plantilla-card-${widget.plantilla.id.name}'),
      button: true,
      selected: widget.seleccionada,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        onShowHoverHighlight: (valor) {
          if (_hover != valor) setState(() => _hover = valor);
        },
        onShowFocusHighlight: (valor) {
          if (_focused != valor) setState(() => _focused = valor);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hover ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: const Color(0xFF111D33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: destacada ? azulAcento : marinoCard,
                  width: widget.seleccionada ? 2 : 1,
                ),
                boxShadow: _hover
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Miniatura estilizada del molde ──
                    Container(
                      height: 90,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [paleta[0], paleta[1]],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            width: 46,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.plantilla.nombre,
                            style: const TextStyle(
                              color: blancoPuro,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (widget.seleccionada)
                          const Icon(Icons.check_circle, color: azulAcento),
                      ],
                    ),

                    Text(
                      widget.plantilla.rubroSugerido,
                      style: const TextStyle(
                        color: azulAcento,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      widget.plantilla.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: grisTenue, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
