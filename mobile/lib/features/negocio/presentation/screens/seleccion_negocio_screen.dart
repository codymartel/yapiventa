import 'package:flutter/material.dart';

import '../widgets/seleccion_negocio_content.dart';

class SeleccionNegocioScreen extends StatefulWidget {
  final String rubroInicial;
  final Future<bool> Function(String rubro) onTipoSeleccionado;
  final VoidCallback onVolverDashboard;

  const SeleccionNegocioScreen({
    super.key,
    this.rubroInicial = '',
    required this.onTipoSeleccionado,
    required this.onVolverDashboard,
  });

  @override
  State<SeleccionNegocioScreen> createState() => _SeleccionNegocioScreenState();
}

class _SeleccionNegocioScreenState extends State<SeleccionNegocioScreen> {
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
    final guardado = await widget.onTipoSeleccionado(rubro);
    if (!mounted) return;
    if (!guardado) {
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar el rubro. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeleccionNegocioContent.fondo,
      body: SafeArea(
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
                      onPressed: _guardando ? null : widget.onVolverDashboard,
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
                  setState(() => _rubroSeleccionado = rubro);
                },
                onConfirmar: _confirmar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
