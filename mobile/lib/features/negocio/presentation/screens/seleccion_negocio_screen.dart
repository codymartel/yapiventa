import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════
// SeleccionNegocioScreen (versión Flutter)
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Es el port a Flutter/Dart de la pantalla original en Kotlin/Compose
// (SeleccionNegocioScreen.kt). Muestra una grilla de rubros de negocio
// para que el usuario elija a qué se dedica su tienda (Bodega,
// Restaurante, Ropa, Farmacia, Ferretería, Otros) y dispara un callback
// con el nombre del rubro elegido.
//
// QUÉ SE MANTUVO IGUAL que la versión Kotlin (a propósito, sin tocar):
// - Los mismos colores exactos (fondoNegro, marinoCard, azulAcento, etc).
// - Los mismos 6 rubros con sus mismos emojis.
// - El mismo texto del título, subtítulo y footer/badge.
// - La misma estructura visual: título arriba, grid en el medio, badge
//   de "Configuración de inventario inteligente" abajo.
//
// QUÉ CAMBIÓ (por ser Flutter, no Compose):
// - El grid responsivo ahora se calcula con LayoutBuilder en vez de
//   BoxWithConstraints (es el equivalente directo en Flutter).
// - El efecto hover se hace con MouseRegion en vez de
//   collectIsHoveredAsState(). MouseRegion en Flutter Web/Desktop SÍ
//   detecta el mouse; en mobile (touch) simplemente nunca dispara
//   onEnter/onExit, así que ahí la card se queda simple, tal como
//   pediste.
//
// CÓMO SE USA:
// Navigator.push(context, MaterialPageRoute(
//   builder: (_) => SeleccionNegocioScreen(
//     onTipoSeleccionado: (rubro) { /* ... */ },
//   ),
// ));
// ═════════════════════════════════════════════════════════════════════════

class SeleccionNegocioScreen extends StatefulWidget {
  final void Function(String rubro) onTipoSeleccionado;

  const SeleccionNegocioScreen({super.key, required this.onTipoSeleccionado});

  @override
  State<SeleccionNegocioScreen> createState() => _SeleccionNegocioScreenState();
}

class _SeleccionNegocioScreenState extends State<SeleccionNegocioScreen> {
  String? _rubroSeleccionado;

  // Paleta de colores oficial YapaVenta — idéntica a la versión Kotlin,
  // no se tocó ningún valor hexadecimal.
  static const Color fondoNegro = Color(0xFF000000);
  static const Color marinoCard = Color(0xFF0A1B2E);
  static const Color azulAcento = Color(0xFF1E88E5);
  static const Color marinoBorde = Color(0xFF1A3050);
  static const Color blancoPuro = Color(0xFFFFFFFF);
  static const Color grisTenue = Color(0xFF8FA8C0);

  // Mismos 6 rubros que quedaron después de la investigación de
  // mercado (Bodega, Restaurante, Ropa, Farmacia, Ferretería, Otros).
  // No se modificó esta lista en este paso.
  static const List<_Rubro> _rubros = [
    _Rubro('Bodega', '🏪'),
    _Rubro('Restaurante', '🍽️'),
    _Rubro('Ropa', '👕'),
    _Rubro('Farmacia', '💊'),
    _Rubro('Ferretería', '🔧'),
    _Rubro('Otros', '✨'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoNegro,
      // SafeArea evita que el contenido choque con notch/status bar en
      // mobile. En web no afecta nada, simplemente no hace nada ahí.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ─────────────────────────────────────────────────────────
            // RESPONSIVIDAD: mismos breakpoints que en la versión
            // Kotlin (BoxWithConstraints con maxWidth).
            // <600 = mobile (2 columnas)
            // 600-1000 = tablet / ventana angosta de web (3 columnas)
            // >1000 = desktop / web ancho (4 columnas)
            // ─────────────────────────────────────────────────────────
            final anchoDisponible = constraints.maxWidth;
            final int columnas;
            if (anchoDisponible < 600) {
              columnas = 2;
            } else if (anchoDisponible < 1000) {
              columnas = 3;
            } else {
              columnas = 4;
            }

            // En pantallas muy anchas (web/desktop) centramos el
            // contenido con un ancho máximo, para que no se vea
            // estirado de borde a borde. En mobile, anchoMaximo termina
            // siendo el mismo anchoDisponible (no limita nada).
            final anchoMaximoContenido = anchoDisponible > 1000
                ? 900.0
                : anchoDisponible;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: anchoMaximoContenido),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),

                      // ── Título pequeño superior ("Tu Rubro") ──
                      Text(
                        'TU RUBRO',
                        style: TextStyle(
                          color: azulAcento,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ── Título grande ("¿A qué se dedica tu negocio?") ──
                      Text(
                        '¿A qué se dedica\ntu negocio?',
                        style: TextStyle(
                          color: blancoPuro,
                          fontWeight: FontWeight
                              .w900, // equivalente a FontWeight.Black de Compose
                          fontSize: 32,
                          height: 1.2, // equivalente a lineHeight: 38.sp
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Subtítulo descriptivo ──
                      Text(
                        'Configuraremos las medidas automáticas.',
                        style: TextStyle(color: grisTenue, fontSize: 14),
                      ),

                      const SizedBox(height: 40),

                      // ── Grid de rubros (ocupa el espacio flexible) ──
                      Expanded(
                        child: GridView.builder(
                          itemCount: _rubros.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columnas,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                // childAspectRatio controla el alto de cada
                                // card en relación a su ancho. 130dp de alto
                                // fijo en Compose; acá lo aproximamos con un
                                // ratio que se ve bien en 2-4 columnas.
                                childAspectRatio: 1.3,
                              ),
                          itemBuilder: (context, index) {
                            final rubro = _rubros[index];
                            return _RubroCard(
                              nombre: rubro.nombre,
                              icono: rubro.icono,
                              marinoCard: marinoCard,
                              marinoBorde: marinoBorde,
                              azulAcento: azulAcento,
                              blancoPuro: blancoPuro,
                              seleccionado: _rubroSeleccionado == rubro.nombre,
                              onTap: () {
                                setState(
                                  () => _rubroSeleccionado = rubro.nombre,
                                );
                              },
                            );
                          },
                        ),
                      ),

                      // Equivale a confirmar la opcion elegida antes de
                      // entrar al wizard. El usuario puede cambiar de rubro
                      // tantas veces como quiera hasta tocar este boton.
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _rubroSeleccionado == null
                              ? null
                              : () => widget.onTipoSeleccionado(
                                  _rubroSeleccionado!,
                                ),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Confirmar rubro'),
                        ),
                      ),

                      // ── Footer/badge "Configuración de inventario inteligente" ──
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32, top: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: marinoCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: marinoBorde, width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: azulAcento,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Configuración de inventario inteligente',
                                style: TextStyle(
                                  color: grisTenue,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
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
            );
          },
        ),
      ),
    );
  }
}

// Contenedor simple para nombre + emoji de cada rubro. Equivalente al
// Pair<String, String> que se usaba en la lista de Kotlin.
class _Rubro {
  final String nombre;
  final String icono;
  const _Rubro(this.nombre, this.icono);
}

// ═════════════════════════════════════════════════════════════════════════
// _RubroCard
// ═════════════════════════════════════════════════════════════════════════
// Card individual de cada rubro. Es un StatefulWidget (no Stateless)
// porque necesita guardar internamente si el mouse está encima
// (_hover) para animar la escala y el color de borde — exactamente el
// mismo propósito que collectIsHoveredAsState() en la versión Kotlin.
// ═════════════════════════════════════════════════════════════════════════

class _RubroCard extends StatefulWidget {
  final String nombre;
  final String icono;
  final Color marinoCard;
  final Color marinoBorde;
  final Color azulAcento;
  final Color blancoPuro;
  final bool seleccionado;
  final VoidCallback onTap;

  const _RubroCard({
    required this.nombre,
    required this.icono,
    required this.marinoCard,
    required this.marinoBorde,
    required this.azulAcento,
    required this.blancoPuro,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  State<_RubroCard> createState() => _RubroCardState();
}

class _RubroCardState extends State<_RubroCard> {
  // true solo mientras el mouse está encima de la card. En mobile
  // (pantalla táctil) esto nunca se vuelve true, porque no hay evento
  // de "mouse entra/sale" — por eso ahí la card se queda simple, sin
  // ningún efecto, tal como se pidió.
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // onEnter/onExit solo disparan en web/desktop con mouse real.
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          // Escala 1.03x al hacer hover — mismo valor que se usó en
          // Compose (animateFloatAsState targetValue 1.03f).
          scale: _hover ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.marinoCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                // El rubro elegido conserva el borde azul hasta confirmar,
                // para que se pueda revisar o cambiar la seleccion.
                color: _hover || widget.seleccionado
                    ? widget.azulAcento
                    : widget.marinoBorde,
                width: widget.seleccionado ? 2 : 1,
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Contenedor del emoji con fondo sutil blanco
                    // translúcido — se intensifica un poco en hover
                    // (0.05 → 0.1 de opacidad), igual que en Kotlin.
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(_hover ? 0.1 : 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.icono,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      widget.nombre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.blancoPuro,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
