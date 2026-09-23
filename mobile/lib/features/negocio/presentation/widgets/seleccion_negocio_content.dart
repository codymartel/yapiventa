import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SeleccionNegocioContent extends StatefulWidget {
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
    _Rubro('Accesorios y regalos', '🎁'),
    _Rubro('Belleza y cuidado personal', '🧴'),
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
  State<SeleccionNegocioContent> createState() =>
      _SeleccionNegocioContentState();
}

class _SeleccionNegocioContentState extends State<SeleccionNegocioContent> {
  static const _marinoCard = SeleccionNegocioContent._marinoCard;
  static const _azulAcento = SeleccionNegocioContent._azulAcento;
  static const _marinoBorde = SeleccionNegocioContent._marinoBorde;
  static const _blancoPuro = SeleccionNegocioContent._blancoPuro;
  static const _grisTenue = SeleccionNegocioContent._grisTenue;
  late final List<FocusNode> _focos = List.generate(
    SeleccionNegocioContent._rubros.length,
    (index) => FocusNode(debugLabel: 'rubro-$index'),
  );

  @override
  void dispose() {
    for (final foco in _focos) {
      foco.dispose();
    }
    super.dispose();
  }

  void _moverFoco(int index, _DireccionRubro direccion, int columnas) {
    final fila = index ~/ columnas;
    final columna = index % columnas;
    final total = SeleccionNegocioContent._rubros.length;
    final destino = switch (direccion) {
      _DireccionRubro.izquierda when columna > 0 => index - 1,
      _DireccionRubro.derecha
          when columna < columnas - 1 && index + 1 < total =>
        index + 1,
      _DireccionRubro.arriba when fila > 0 => index - columnas,
      _DireccionRubro.abajo when index + columnas < total => index + columnas,
      _ => index,
    };
    _focos[destino].requestFocus();
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
                        for (
                          var index = 0;
                          index < SeleccionNegocioContent._rubros.length;
                          index++
                        )
                          SizedBox(
                            width: anchoTarjeta,
                            child: _RubroCard(
                              focusNode: _focos[index],
                              nombre:
                                  SeleccionNegocioContent._rubros[index].nombre,
                              icono:
                                  SeleccionNegocioContent._rubros[index].icono,
                              seleccionado:
                                  widget.rubroSeleccionado ==
                                  SeleccionNegocioContent._rubros[index].nombre,
                              habilitado: !widget.guardando,
                              onMover: (direccion) =>
                                  _moverFoco(index, direccion, columnas),
                              onTap: () => widget.onRubroSeleccionado(
                                SeleccionNegocioContent._rubros[index].nombre,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('confirmar-rubro'),
                        onPressed:
                            widget.rubroSeleccionado == null || widget.guardando
                            ? null
                            : widget.onConfirmar,
                        icon: widget.guardando
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                        label: Text(
                          widget.guardando ? 'Guardando...' : 'Confirmar rubro',
                        ),
                      ),
                    ),
                    if (widget.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.error!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
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

enum _DireccionRubro { izquierda, derecha, arriba, abajo }

class _MoverRubroIntent extends Intent {
  final _DireccionRubro direccion;

  const _MoverRubroIntent(this.direccion);
}

class _Rubro {
  final String nombre;
  final String icono;

  const _Rubro(this.nombre, this.icono);
}

class _RubroCard extends StatefulWidget {
  final FocusNode focusNode;
  final String nombre;
  final String icono;
  final bool seleccionado;
  final bool habilitado;
  final ValueChanged<_DireccionRubro> onMover;
  final VoidCallback onTap;

  const _RubroCard({
    required this.focusNode,
    required this.nombre,
    required this.icono,
    required this.seleccionado,
    required this.habilitado,
    required this.onMover,
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
        focusNode: widget.focusNode,
        enabled: widget.habilitado,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _MoverRubroIntent(
            _DireccionRubro.izquierda,
          ),
          SingleActivator(LogicalKeyboardKey.arrowRight): _MoverRubroIntent(
            _DireccionRubro.derecha,
          ),
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoverRubroIntent(
            _DireccionRubro.arriba,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoverRubroIntent(
            _DireccionRubro.abajo,
          ),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
          _MoverRubroIntent: CallbackAction<_MoverRubroIntent>(
            onInvoke: (intent) {
              widget.onMover(intent.direccion);
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
