import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════
// SeleccionPlantillaScreen
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Muestra una grilla de plantillas web disponibles (los 4 moldes que
// viven en web/public/moldes/) para que el usuario elija el estilo de su
// tienda virtual: NEON (tech/electrónica), CRISTAL (farmacia/ferretería),
// SABROSO (restaurante) y GALERIA (ropa/moda). Dispara un callback con el
// identificador de la plantilla elegida.
//
// Se inspira en el mismo layout que SeleccionNegocioScreen: paleta
// YapaVenta oscura, tarjetas con hover en web/desktop y sin efecto en
// touch, botón de confirmación al final.
//
// CÓMO SE USA:
// Navigator.push(context, MaterialPageRoute(
//   builder: (_) => SeleccionPlantillaScreen(
//     rubro: rubro,          // opcional, para mostrar un subtítulo contextual
//     plantillaActual: 'neon', // opcional, preselecciona la plantilla guardada
//     onPlantillaSeleccionada: (plantilla) { /* "neon", "cristal", ... */ },
//   ),
// ));
//
// El id de cada plantilla coincide con el nombre de su carpeta en
// web/public/moldes/{id}/, de modo que la web pueda construir la URL
// final de la tienda sin traducciones extra.
// ═════════════════════════════════════════════════════════════════════════

class SeleccionPlantillaScreen extends StatefulWidget {
  /// Rubro del negocio (Bodega, Restaurante, Ropa, Farmacia, Ferretería…).
  /// Solo se usa para el subtítulo; no condiciona la selección.
  final String rubro;

  /// Plantilla ya guardada del negocio ('' si aún no eligió ninguna).
  /// Sirve para preseleccionar la tarjeta al reabrir la pantalla.
  final String plantillaActual;
  final void Function(String plantilla) onPlantillaSeleccionada;

  const SeleccionPlantillaScreen({
    super.key,
    this.rubro = '',
    this.plantillaActual = '',
    required this.onPlantillaSeleccionada,
  });

  @override
  State<SeleccionPlantillaScreen> createState() =>
      _SeleccionPlantillaScreenState();
}

class _SeleccionPlantillaScreenState extends State<SeleccionPlantillaScreen> {
  late String _plantillaSeleccionada;

  @override
  void initState() {
    super.initState();
    _plantillaSeleccionada = widget.plantillaActual;
  }

  // Paleta oficial YapaVenta — la misma de SeleccionNegocioScreen.
  static const Color fondo = Color(0xFF070C18);
  static const Color marinoCard = Color(0xFF0A1B2E);
  static const Color azulAcento = Color(0xFF1E88E5);
  static const Color marinoBorde = Color(0xFF1A3050);
  static const Color blancoPuro = Color(0xFFFFFFFF);
  static const Color grisTenue = Color(0xFF8FA8C0);

  static const List<Plantilla> _plantillas = [
    Plantilla(
      id: 'neon',
      nombre: 'Neon',
      rubroSugerido: 'Tech / Electrónica',
      descripcion:
          'Fondo oscuro con acentos verde-cian. Ideal para productos tecnológicos.',
    ),
    Plantilla(
      id: 'cristal',
      nombre: 'Cristal',
      rubroSugerido: 'Farmacia / Ferretería',
      descripcion:
          'Fondo claro, mucho espacio en blanco y sombras suaves. Sensación limpia y confiable.',
    ),
    Plantilla(
      id: 'sabroso',
      nombre: 'Sabroso',
      rubroSugerido: 'Restaurante',
      descripcion:
          'Fondo crema cálido con naranja quemado. La comida es la protagonista.',
    ),
    Plantilla(
      id: 'galeria',
      nombre: 'Galería',
      rubroSugerido: 'Ropa / Moda',
      descripcion:
          'Morado pastel, tipografía serif y lookbook de fotos. Con carrito en la tienda.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final anchoDisponible = constraints.maxWidth;
            final int columnas;
            if (anchoDisponible < 600) {
              columnas = 2;
            } else if (anchoDisponible < 1000) {
              columnas = 2;
            } else {
              columnas = 4;
            }

            final anchoMaximoContenido = anchoDisponible > 1000
                ? 980.0
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

                      Text(
                        'PLANTILLA',
                        style: TextStyle(
                          color: azulAcento,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Elige el estilo\nde tu tienda',
                        style: TextStyle(
                          color: blancoPuro,
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        widget.rubro.isEmpty
                            ? 'Se aplicará automáticamente a tu catálogo.'
                            : 'Se verá con tus productos de ${widget.rubro}.',
                        style: TextStyle(
                          color: grisTenue,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 40),

                      Expanded(
                        child: GridView.builder(
                          itemCount: _plantillas.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columnas,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.15,
                              ),
                          itemBuilder: (context, index) {
                            final plantilla = _plantillas[index];
                            return _PlantillaCard(
                              plantilla: plantilla,
                              seleccionada:
                                  _plantillaSeleccionada == plantilla.id,
                              onTap: () {
                                setState(
                                  () => _plantillaSeleccionada = plantilla.id,
                                );
                              },
                            );
                          },
                        ),
                      ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _plantillaSeleccionada.isEmpty
                              ? null
                              : () => widget.onPlantillaSeleccionada(
                                  _plantillaSeleccionada,
                                ),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Confirmar plantilla'),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Botones: Ver tienda web + Ir al inicio ──
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Ver tienda web
                          SizedBox(
                            width: anchoDisponible < 500
                                ? double.infinity
                                : (anchoMaximoContenido - 48 - 12) / 2,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'La vista web estará disponible próximamente',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.open_in_new,
                                size: 18,
                              ),
                              label: const Text('Ver tienda web'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: azulAcento,
                                side: const BorderSide(
                                  color: azulAcento,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          // Ir al inicio
                          SizedBox(
                            width: anchoDisponible < 500
                                ? double.infinity
                                : (anchoMaximoContenido - 48 - 12) / 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/home',
                                );
                              },
                              icon: const Icon(
                                Icons.home_outlined,
                                size: 18,
                              ),
                              label: const Text('Ir al inicio'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: azulAcento,
                                foregroundColor: blancoPuro,
                                padding: const EdgeInsets.symmetric(
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
                            color: marinoCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: marinoBorde, width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: azulAcento,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Puedes cambiar tu plantilla cuando quieras',
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

// Modelo simple de plantilla. El `id` coincide 1:1 con la carpeta del
// molde en web/public/moldes/{id}/.
class Plantilla {
  final String id;
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
// web/desktop, igual que _RubroCard de SeleccionNegocioScreen.
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

  // Paleta de la miniatura — degradado que representa cada molde web.
  static const Map<String, List<Color>> _paletas = {
    'neon': [Color(0xFF00FF88), Color(0xFF0A0A0F)],
    'cristal': [Color(0xFF8ED1B8), Color(0xFFF6F7F9)],
    'sabroso': [Color(0xFFE65100), Color(0xFFFAF6F0)],
    'galeria': [Color(0xFF6C45A8), Color(0xFFF4F1FB)],
  };

  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final paleta = _paletas[widget.plantilla.id] ??
        const [Color(0xFF1E88E5), Color(0xFF0A1B2E)];

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
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
                color: _hover || widget.seleccionada
                    ? azulAcento
                    : marinoCard,
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
                          style: TextStyle(
                            color: blancoPuro,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (widget.seleccionada)
                        Icon(Icons.check_circle, color: azulAcento, size: 18),
                    ],
                  ),

                  Text(
                    widget.plantilla.rubroSugerido,
                    style: TextStyle(
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
                    style: TextStyle(color: grisTenue, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}