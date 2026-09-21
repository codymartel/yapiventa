import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SeleccionNegocioContent extends StatelessWidget {
  static const fondo = Color(0xFF000000);
  static const _marinoCard = Color(0xFF0A1B2E);
  static const _azulAcento = Color(0xFF1E88E5);
  static const _marinoBorde = Color(0xFF1A3050);
  static const _blancoPuro = Color(0xFFFFFFFF);
  static const _grisTenue = Color(0xFF8FA8C0);

  static const _rubros = [
    _Rubro('Bodega', '🏪'),
    _Rubro('Restaurante', '🍽️'),
    _Rubro('Ropa', '👕'),
    _Rubro('Farmacia', '💊'),
    _Rubro('Ferretería', '🔧'),
    _Rubro('Otros', '✨'),
  ];

  final String? rubroSeleccionado;
  final bool guardando;
  final String? error;
  final ValueChanged<String> onRubroSeleccionado;
  final VoidCallback onConfirmar;

  const SeleccionNegocioContent({
    super.key,
    required this.rubroSeleccionado,
    required this.guardando,
    required this.error,
    required this.onRubroSeleccionado,
    required this.onConfirmar,
  });

  static bool esRubroDisponible(String rubro) {
    return _rubros.any((opcion) => opcion.nombre == rubro);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoContenido = math.min(constraints.maxWidth, 900.0);
        final paddingHorizontal = constraints.maxWidth < 600 ? 16.0 : 24.0;
        final anchoTarjetas = math.max(
          0.0,
          anchoContenido - paddingHorizontal * 2,
        );
        final columnas = anchoTarjetas >= 780
            ? 3
            : anchoTarjetas >= 420
            ? 2
            : 1;
        const separacion = 16.0;
        final anchoTarjeta =
            (anchoTarjetas - separacion * (columnas - 1)) / columnas;

        return SingleChildScrollView(
          key: const Key('seleccion-negocio-scroll'),
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: SizedBox(
              width: anchoContenido,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  paddingHorizontal,
                  0,
                  paddingHorizontal,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TU RUBRO',
                      style: TextStyle(
                        color: _azulAcento,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '¿A qué se dedica\ntu negocio?',
                      style: TextStyle(
                        color: _blancoPuro,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Configuraremos las medidas automáticas.',
                      style: TextStyle(color: _grisTenue, fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                    Wrap(
                      key: const Key('rubros-wrap'),
                      spacing: separacion,
                      runSpacing: separacion,
                      children: [
                        for (final rubro in _rubros)
                          SizedBox(
                            width: anchoTarjeta,
                            child: _RubroCard(
                              nombre: rubro.nombre,
                              icono: rubro.icono,
                              seleccionado: rubroSeleccionado == rubro.nombre,
                              habilitado: !guardando,
                              onTap: () => onRubroSeleccionado(rubro.nombre),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('confirmar-rubro'),
                        onPressed: rubroSeleccionado == null || guardando
                            ? null
                            : onConfirmar,
                        icon: guardando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                        label: Text(
                          guardando ? 'Guardando...' : 'Confirmar rubro',
                        ),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _marinoCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _marinoBorde),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: _azulAcento,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Configuración de inventario inteligente',
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

class _Rubro {
  final String nombre;
  final String icono;

  const _Rubro(this.nombre, this.icono);
}

class _RubroCard extends StatefulWidget {
  final String nombre;
  final String icono;
  final bool seleccionado;
  final bool habilitado;
  final VoidCallback onTap;

  const _RubroCard({
    required this.nombre,
    required this.icono,
    required this.seleccionado,
    required this.habilitado,
    required this.onTap,
  });

  @override
  State<_RubroCard> createState() => _RubroCardState();
}

class _RubroCardState extends State<_RubroCard> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final destacada = widget.seleccionado || _hover || _focused;
    return Semantics(
      key: Key('rubro-card-${widget.nombre}'),
      button: true,
      selected: widget.seleccionado,
      enabled: widget.habilitado,
      onTap: widget.habilitado ? widget.onTap : null,
      child: FocusableActionDetector(
        enabled: widget.habilitado,
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
          onTap: widget.habilitado ? widget.onTap : null,
          child: AnimatedOpacity(
            opacity: widget.habilitado ? 1 : 0.55,
            duration: const Duration(milliseconds: 150),
            child: AnimatedScale(
              scale: _hover && widget.habilitado ? 1.03 : 1,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: const BoxConstraints(minHeight: 124),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SeleccionNegocioContent._marinoCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: destacada
                        ? SeleccionNegocioContent._azulAcento
                        : SeleccionNegocioContent._marinoBorde,
                    width: widget.seleccionado ? 2 : 1,
                  ),
                  boxShadow: _hover && widget.habilitado
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: _hover && widget.habilitado ? 0.1 : 0.05,
                        ),
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
                      style: const TextStyle(
                        color: SeleccionNegocioContent._blancoPuro,
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
