import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/seleccion_plantilla_provider.dart';
import '../widgets/seleccion_plantilla_content.dart';

typedef AbrirUrlTienda =
    Future<bool> Function(Uri url, {String? webOnlyWindowName});

// ═════════════════════════════════════════════════════════════════════════
// SeleccionPlantillaScreen
// ═════════════════════════════════════════════════════════════════════════
//
// Pantalla que muestra una grilla de plantillas web disponibles (los 4
// moldes que viven en web/public/moldes/) para que el usuario elija el
// estilo de su tienda virtual: NEON, CRISTAL, SABROSO y GALERIA.
//
// Esta pantalla conserva el Scaffold, la navegación, la apertura de la
// tienda pública y la coordinación con el provider. Toda la interfaz
// visual vive en SeleccionPlantillaContent, reutilizable dentro del
// dashboard.
// ═════════════════════════════════════════════════════════════════════════

class SeleccionPlantillaScreen extends StatefulWidget {
  /// Rubro del negocio (Bodega, Restaurante, Ropa, Farmacia, Ferretería…).
  /// Solo se usa para el subtítulo; no condiciona la selección.
  final String rubro;

  final Future<void> Function(String plantilla) onPlantillaSeleccionada;
  final AbrirUrlTienda? abrirUrl;

  const SeleccionPlantillaScreen({
    super.key,
    this.rubro = '',
    required this.onPlantillaSeleccionada,
    this.abrirUrl,
  });

  @override
  State<SeleccionPlantillaScreen> createState() =>
      _SeleccionPlantillaScreenState();
}

class _SeleccionPlantillaScreenState extends State<SeleccionPlantillaScreen> {
  bool _finalizando = false;

  Future<void> _finalizar() async {
    if (_finalizando) return;
    setState(() => _finalizando = true);
    final provider = context.read<SeleccionPlantillaProvider>();
    final guardado = await provider.guardar();
    if (!mounted) return;
    if (!guardado) {
      setState(() => _finalizando = false);
      _mostrarMensaje(
        provider.errorMessage ??
            'No se pudo guardar la plantilla web. Intenta de nuevo.',
      );
      return;
    }

    await widget.onPlantillaSeleccionada(
      provider.seleccionTemporal!.valorPersistencia,
    );
    if (mounted) setState(() => _finalizando = false);
  }

  Future<void> _verTiendaWeb() async {
    final provider = context.read<SeleccionPlantillaProvider>();
    if (!provider.cargado ||
        provider.plantillaGuardada == null ||
        provider.slug.isEmpty) {
      _mostrarMensaje('La vista web estará disponible próximamente');
      return;
    }

    final url = Uri.https('yapiventa-tienda.web.app', '/${provider.slug}');
    try {
      final abrirUrl = widget.abrirUrl ?? launchUrl;
      final abierto = await abrirUrl(url, webOnlyWindowName: '_blank');
      if (!abierto && mounted) {
        _mostrarMensaje('El navegador no pudo abrir la tienda web.');
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error al abrir la tienda publica (${url.host}): '
        '${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _mostrarMensaje(
          'Ocurrió un error al abrir la tienda web. Intenta de nuevo.',
        );
      }
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final seleccionProvider = context.watch<SeleccionPlantillaProvider>();
    final guardando = seleccionProvider.guardando || _finalizando;

    return PopScope(
      canPop: !guardando,
      child: Scaffold(
        backgroundColor: SeleccionPlantillaContent.fondo,
        body: SafeArea(
          child: SeleccionPlantillaContent(
            rubro: widget.rubro,
            plantillaSeleccionada: seleccionProvider.seleccionTemporal,
            plantillaGuardada: seleccionProvider.plantillaGuardada,
            cargando: seleccionProvider.cargando,
            cargado: seleccionProvider.cargado,
            guardando: guardando,
            cambiosPendientes: seleccionProvider.cambiosPendientes,
            error: seleccionProvider.errorMessage,
            onSeleccionarPlantilla: seleccionProvider.seleccionar,
            onFinalizar: _finalizar,
            onVerTienda: _verTiendaWeb,
            onIrDashboard: () =>
                Navigator.pushReplacementNamed(context, '/home'),
          ),
        ),
      ),
    );
  }
}
