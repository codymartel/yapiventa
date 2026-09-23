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
// - Coordina GUARDAR, VER TIENDA y FINALIZAR por separado:
//    * Guardar: persiste la selección (provider.guardar()), recarga el
//      progreso (recargarProgreso) y se queda en Plantilla. Solo Finalizar
//      queda armado si esa recarga terminó correctamente.
//    * Ver tienda: solo abre la tienda (onVerTienda) si ya hay una plantilla
//      guardada y slug; no guarda.
//    * Finalizar: NO guarda; solo avisa al embebedor (onCompletado) para
//      volver al inicio. Se habilita cuando la selección coincide con la
//      guardada, la recarga terminó bien y no hay cambios pendientes.
// - Mantiene bloqueada toda la interacción (PopScope + AbsorbPointer) durante
//   el guardado y la recarga (evita doble clic y retroceso a mitad).
//   En caso de error de guardado o recarga, mantiene al usuario en Plantilla.
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

  /// Finalizar: se avisa al embebedor para volver al inicio. No recibe
  /// plantilla: el guardado ya lo hizo el botón "Guardar" de este flujo.
  final VoidCallback onCompletado;

  /// Abre la tienda pública del slug dado (lo hace el embebedor).
  final Future<void> Function(String slug) onVerTienda;

  /// Recarga el progreso de la sesión tras un guardado exitoso (p. ej.
  /// acceso.recargar()). Se espera con la interacción aún bloqueada; el
  /// flujo se queda en Plantilla hasta que el usuario decida Finalizar.
  final Future<void> Function()? recargarProgreso;

  const SeleccionPlantillaFlow({
    super.key,
    required this.uid,
    this.rubro = '',
    this.seleccionInicial,
    this.dependencies,
    required this.onVolver,
    required this.onCompletado,
    required this.onVerTienda,
    this.recargarProgreso,
  });

  @override
  State<SeleccionPlantillaFlow> createState() => _SeleccionPlantillaFlowState();
}

class _SeleccionPlantillaFlowState extends State<SeleccionPlantillaFlow> {
  SeleccionPlantillaProvider? _provider;
  bool _operacionEnCurso = false;
  bool _progresoRecargado = true;

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

  Future<void> _guardar() async {
    if (_operacionEnCurso) return;
    final provider = _provider;
    if (provider == null) return;

    setState(() {
      _operacionEnCurso = true;
      _progresoRecargado = false;
    });
    var listo = false;
    var guardoBien = false;
    try {
      guardoBien = await provider.guardar();
      if (guardoBien) {
        final recarga = widget.recargarProgreso;
        if (recarga != null) {
          try {
            await recarga();
            listo = true;
          } catch (_) {
            listo = false;
          }
        } else {
          listo = true;
        }
      }
    } finally {
      if (mounted) setState(() => _operacionEnCurso = false);
    }

    if (!mounted) return;
    if (listo) {
      setState(() => _progresoRecargado = true);
      return;
    }
    _mostrarMensaje(
      guardoBien
          ? 'Se guardó, pero no se pudo refrescar tu progreso. Intenta de nuevo.'
          : provider.errorMessage ??
                'No se pudo guardar la plantilla web. Intenta de nuevo.',
    );
  }

  Future<void> _finalizar() async {
    final provider = _provider;
    if (provider == null || _operacionEnCurso) return;
    if (!provider.cargado ||
        provider.plantillaGuardada == null ||
        provider.cambiosPendientes ||
        !_progresoRecargado) {
      return;
    }
    widget.onCompletado();
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
          final guardando = _operacionEnCurso || p.guardando;
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
                progresoRecargado: _progresoRecargado,
                error: p.errorMessage,
                onSeleccionarPlantilla: p.seleccionar,
                onGuardar: _guardar,
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
