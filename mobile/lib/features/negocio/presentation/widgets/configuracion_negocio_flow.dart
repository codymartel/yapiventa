import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/configuracion_negocio_provider.dart';
import 'configuracion_negocio_content.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfiguracionNegocioFlow
// ═════════════════════════════════════════════════════════════════════════
// Coordinador reutilizable del wizard de 4 pasos (patrón SeleccionNegocioFlow).
//
// QUÉ HACE:
// - Coordina el guardado (context.read<ConfiguracionNegocioProvider>.
//   guardar(uid)) y la recarga del progreso (onRecargarProgreso) que
//   actualiza el estado de la sesión tras guardar.
// - Mantiene bloqueada toda la interacción (PopScope + AbsorbPointer) hasta
//   que TERMINEN tanto el guardado como la recarga — evita doble clic y
//   navegación atrás a mitad de operación.
// - Decide cuándo completar (onCompletado) y cuándo volver (onVolver).
// - En caso de error de guardado (o recarga), mantiene al usuario dentro
//   de Configuración: no completa ni navega.
//
// QUÉ NO HACE:
// - NO crea Scaffold, AppBar ni SafeArea (los provee quien lo embebe).
// - NO crea providers — reutiliza el ConfiguracionNegocioProvider que ya
//   existe más arriba en el árbol (se crea en main.dart).
// - NO usa Navigator ni crea repositorios: se delega vía callbacks.
// ═════════════════════════════════════════════════════════════════════════

class ConfiguracionNegocioFlow extends StatefulWidget {
  final String uid;
  final String? negocioId;
  final VoidCallback onVolver;
  final VoidCallback onCompletado;

  /// Recarga el progreso de la sesión tras un guardado exitoso (p. ej.
  /// acceso.recargar()). Se espera con la interacción aún bloqueada.
  final Future<void> Function(String uid, String? negocioId)? onRecargarProgreso;

  const ConfiguracionNegocioFlow({
    super.key,
    required this.uid,
    this.negocioId,
    required this.onVolver,
    required this.onCompletado,
    this.onRecargarProgreso,
  });

  @override
  State<ConfiguracionNegocioFlow> createState() =>
      _ConfiguracionNegocioFlowState();
}

class _ConfiguracionNegocioFlowState extends State<ConfiguracionNegocioFlow> {
  bool _finalizando = false;

  Future<void> _finalizar() async {
    if (_finalizando) return;
    final p = context.read<ConfiguracionNegocioProvider>();
    setState(() => _finalizando = true);

    var completado = false;
    try {
      final exito = await p.guardar(widget.uid);
      if (exito) {
        completado = true;
        final recarga = widget.onRecargarProgreso;
        if (recarga != null) {
          try {
            await recarga(widget.uid, widget.negocioId);
          } catch (_) {
            completado = false;
          }
        }
      }
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }

    if (completado && mounted) widget.onCompletado();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return PopScope(
      canPop: !_finalizando,
      child: AbsorbPointer(
        absorbing: _finalizando,
        child: ConfiguracionNegocioContent(
          rubro: p.rubro,
          onVolver: widget.onVolver,
          onFinalizar: _finalizar,
        ),
      ),
    );
  }
}