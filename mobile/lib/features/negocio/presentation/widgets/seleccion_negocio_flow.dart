import 'package:flutter/material.dart';

import 'seleccion_negocio_content.dart';

class SeleccionNegocioFlow extends StatefulWidget {
  final String rubroInicial;
  final Future<bool> Function(String rubro) onTipoSeleccionado;
  final ValueChanged<String>? onRubroCambiado;
  final VoidCallback onCompletado;
  final VoidCallback onVolver;

  const SeleccionNegocioFlow({
    super.key,
    this.rubroInicial = '',
    required this.onTipoSeleccionado,
    this.onRubroCambiado,
    required this.onCompletado,
    required this.onVolver,
  });

  @override
  State<SeleccionNegocioFlow> createState() => _SeleccionNegocioFlowState();
}

class _SeleccionNegocioFlowState extends State<SeleccionNegocioFlow> {
  String? _rubroSeleccionado;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (SeleccionNegocioContent.esRubroDisponible(widget.rubroInicial)) {
      _rubroSeleccionado = widget.rubroInicial;
    }
  }

  Future<void> _confirmar() async {
    final rubro = _rubroSeleccionado;
    if (rubro == null || _guardando) return;
    if (widget.rubroInicial.isNotEmpty && widget.rubroInicial != rubro) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambiar rubro'),
          content: const Text(
            'Deberás revisar la configuración del negocio. Tus productos '
            'no se borrarán y sólo se pedirá corregir los que resulten incompatibles.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cambiar y revisar'),
            ),
          ],
        ),
      );
      if (continuar != true || !mounted) return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    String? error;
    var guardado = false;
    try {
      guardado = await widget.onTipoSeleccionado(rubro);
      if (!guardado) {
        error = 'No se pudo guardar el rubro. Intenta de nuevo.';
      }
    } catch (_) {
      error = 'No se pudo guardar el rubro. Intenta de nuevo.';
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = error;
        });
      }
    }
    if (guardado && mounted) {
      widget.onCompletado();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Volver al dashboard',
                    onPressed: _guardando ? null : widget.onVolver,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SeleccionNegocioContent(
              rubroSeleccionado: _rubroSeleccionado,
              guardando: _guardando,
              error: _error,
              onRubroSeleccionado: (rubro) {
                if (_guardando) return;
                setState(() => _rubroSeleccionado = rubro);
                widget.onRubroCambiado?.call(rubro);
              },
              onConfirmar: _confirmar,
            ),
          ),
        ],
      ),
    );
  }
}
