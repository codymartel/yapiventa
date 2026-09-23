import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/seleccion_plantilla_info.dart';
import '../../seleccion_plantilla_dependencies.dart';
import '../providers/seleccion_plantilla_provider.dart';
import 'seleccion_plantilla_content.dart';

// ═════════════════════════════════════════════════════════════════════════
// SeleccionPlantillaFlow
// ═════════════════════════════════════════════════════════════════════════
// Coordinador reutilizable de la selección de plantilla web (patrón
// ProductosFlow/ConfiguracionNegocioFlow). Crea una sola instancia del
// SeleccionPlantillaProvider con dependencias inyectables (por defecto
// production()), dispara la carga inicial y monta SeleccionPlantillaContent.
// Se puede embeber tanto en la ruta independiente /elegir-plantilla como
// dentro del dashboard.
//
// QUÉ HACE:
// - Crea el SeleccionPlantillaProvider en initState (una sola vez, identidad
//   estable entre reconstrucciones) y lo libera en dispose.
// - Dispara la carga inicial (cargar()); con [seleccionInicial] no relee el
//   repositorio.
// - Coordina la selección temporal, la finalización/guardado (guardar()), el
//   bloqueo contra doble clic (guardando = _finalizando || provider.guardando)
//   con AbsorbPointer, la navegación atrás bloqueada (PopScope) y el manejo
//   de errores (mantiene al usuario en Plantilla).
// - Decide cuándo invocar onVerTienda (solo si hay slug y plantilla guardada),
//   onVolver (botón "Ir al dashboard" = volver sin guardar) y onCompletado
//   (guardado exitoso).
//
// QUÉ NO HACE:
// - NO crea Scaffold, AppBar ni SafeArea (los provee quien lo embebe).
// - NO navega a rutas raíz ni abre URLs: url_launcher queda en el
//   embebedor (callback onVerTienda) y la navegación se delega vía callbacks
//   (onVolver, onCompletado). Tampoco usa Firebase ni repositorios directos:
//   se delega vía dependencias inyectables.
// ═════════════════════════════════════════════════════════════════════════

class SeleccionPlantillaFlow extends StatefulWidget {
  final String uid;
  final String rubro;
  final SeleccionPlantillaInfo? seleccionInicial;
  final SeleccionPlantillaDependencies? dependencies;

  /// Regresa a donde estaba el embebedor (botón "Ir al dashboard").
  final VoidCallback onVolver;

  /// Guardado exitoso; recibe la plantilla persistida (valor de persistencia).
  final Future<void> Function(String plantilla) onCompletado;

  /// Abre la tienda pública del slug dado (lo hace el embebedor).
  final Future<void> Function(String slug) onVerTienda;

  const SeleccionPlantillaFlow({
    super.key,
    required this.uid,
    this.rubro = '',
    this.seleccionInicial,
    this.dependencies,
    required this.onVolver,
    required this.onCompletado,
    required this.onVerTienda,
  });

  @override
  State<SeleccionPlantillaFlow> createState() => _SeleccionPlantillaFlowState();
}

class _SeleccionPlantillaFlowState extends State<SeleccionPlantillaFlow> {
  SeleccionPlantillaProvider? _provider;
  bool _finalizando = false;

  @override
  void initState() {
    super.initState();
    final dependencies =
        widget.dependencies ?? SeleccionPlantillaDependencies.production();
    _provider = SeleccionPlantillaProvider(
      uid: widget.uid,
      obtenerSeleccionPlantilla: dependencies.obtenerSeleccionPlantilla,
      guardarPlantillaWeb: dependencies.guardarPlantillaWeb,
      seleccionInicial: widget.seleccionInicial,
    )..cargar();
  }

  @override
  void dispose() {
    _provider?.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    if (_finalizando) return;
    final provider = _provider;
    if (provider == null) return;

    setState(() => _finalizando = true);
    var completado = false;
    String? plantilla;
    try {
      final exito = await provider.guardar();
      if (exito) {
        plantilla = provider.seleccionTemporal?.valorPersistencia;
        completado = plantilla != null;
      }
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }

    if (mounted && !completado) {
      _mostrarMensaje(
        provider.errorMessage ??
            'No se pudo guardar la plantilla web. Intenta de nuevo.',
      );
      return;
    }

    if (completado && mounted) {
      try {
        await widget.onCompletado(plantilla!);
      } catch (_) {
        // El embebedor decide cómo recuperarse; aquí solo se rearma la UI.
      }
    }
  }

  Future<void> _verTienda() async {
    final provider = _provider;
    if (provider == null) return;
    if (!provider.cargado ||
        provider.plantillaGuardada == null ||
        provider.slug.isEmpty) {
      _mostrarMensaje('La vista web estará disponible próximamente');
      return;
    }
    await widget.onVerTienda(provider.slug);
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return const SizedBox.shrink();

    return ChangeNotifierProvider.value(
      value: provider,
      child: Consumer<SeleccionPlantillaProvider>(
        builder: (context, p, _) {
          final guardando = _finalizando || p.guardando;
          return PopScope(
            canPop: !guardando,
            child: AbsorbPointer(
              absorbing: guardando,
              child: SeleccionPlantillaContent(
                rubro: widget.rubro,
                plantillaSeleccionada: p.seleccionTemporal,
                plantillaGuardada: p.plantillaGuardada,
                cargando: p.cargando,
                cargado: p.cargado,
                guardando: guardando,
                cambiosPendientes: p.cambiosPendientes,
                error: p.errorMessage,
                onSeleccionarPlantilla: p.seleccionar,
                onFinalizar: _finalizar,
                onVerTienda: _verTienda,
                onIrDashboard: widget.onVolver,
              ),
            ),
          );
        },
      ),
    );
  }
}
