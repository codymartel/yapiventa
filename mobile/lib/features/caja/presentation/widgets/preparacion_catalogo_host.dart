import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/tamanos_caja.dart';
import '../providers/preparacion_catalogo_provider.dart';
import 'contenido_preparacion_catalogo.dart';

// ═════════════════════════════════════════════════════════════════════════
// PreparacionCatalogoHost
// ═════════════════════════════════════════════════════════════════════════
// Envuelve la pantalla de Caja. Pregunta si hace falta preparar el catálogo
// (1 lectura, nada se escribe) y, si hace falta, muestra el aviso:
//   - menos de 1 100 px (celular y tableta): hoja desde abajo;
//   - 1 100 px o más (PC y TV): diálogo centrado.
// El mismo modal acompaña todo el proceso (aviso → preparando → listo, error
// o «demasiados»). Mientras prepara NO se puede cerrar (atrás ni tocar fuera).
// Cerrarlo en cualquier otro estado equivale a «Más tarde» (o a «Empezar a
// vender» si ya estaba listo).
//
// Avisa por callbacks cuando el catálogo queda listo (para que Caja vuelva a
// cargarlo) y cuando cambia el bloqueo de ventas (para apagar «Cobrar»).
// ═════════════════════════════════════════════════════════════════════════
class PreparacionCatalogoHost extends StatefulWidget {
  const PreparacionCatalogoHost({
    super.key,
    required this.provider,
    required this.child,
    this.alQuedarLista,
    this.alCambiarBloqueo,
  });

  /// 1 100 px: desde aquí el aviso es un diálogo (menos, una hoja), igual
  /// que las demás hojas de Caja.
  static const double anchoDialogo = TamanosCaja.anchoPc;

  final PreparacionCatalogoProvider provider;
  final Widget child;

  /// El catálogo acaba de prepararse: conviene recargar la lista de Caja.
  final VoidCallback? alQuedarLista;

  /// Las ventas se bloquean (true) o se liberan (false).
  final ValueChanged<bool>? alCambiarBloqueo;

  @override
  State<PreparacionCatalogoHost> createState() =>
      _PreparacionCatalogoHostState();
}

class _PreparacionCatalogoHostState extends State<PreparacionCatalogoHost> {
  bool _abierto = false;
  bool _abriendo = false;
  bool _bloqueoAnterior = false;
  EstadoPreparacion _estadoAnterior = EstadoPreparacion.desconocido;

  /// Lo último que se mostró: así, mientras el modal se cierra, no cambia de
  /// contenido a mitad de la animación.
  EstadoPreparacion _ultimoMostrado = EstadoPreparacion.pideConfirmar;
  BuildContext? _contextoModal;

  PreparacionCatalogoProvider get _p => widget.provider;

  @override
  void initState() {
    super.initState();
    _p.addListener(_alCambiar);
    _p.verificar();
    WidgetsBinding.instance.addPostFrameCallback((_) => _alCambiar());
  }

  @override
  void didUpdateWidget(PreparacionCatalogoHost anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.provider != widget.provider) {
      anterior.provider.removeListener(_alCambiar);
      widget.provider.addListener(_alCambiar);
      widget.provider.verificar();
    }
  }

  @override
  void dispose() {
    _p.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    if (_p.bloqueaVentas != _bloqueoAnterior) {
      _bloqueoAnterior = _p.bloqueaVentas;
      widget.alCambiarBloqueo?.call(_bloqueoAnterior);
    }
    if (_p.estado == EstadoPreparacion.lista &&
        _estadoAnterior != EstadoPreparacion.lista) {
      widget.alQuedarLista?.call();
    }
    _estadoAnterior = _p.estado;
    if (_p.hayQueMostrar) _ultimoMostrado = _p.estado;

    if (_p.hayQueMostrar && !_abierto && !_abriendo) {
      _abriendo = true;
      // Nunca se abre un modal en medio de un build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrir());
    } else if (!_p.hayQueMostrar && _abierto) {
      final contexto = _contextoModal;
      if (contexto != null && contexto.mounted) {
        Navigator.of(contexto).pop();
      }
    }
  }

  Future<void> _abrir() async {
    _abriendo = false;
    if (!mounted || _abierto || !_p.hayQueMostrar) return;
    _abierto = true;
    final ancho = MediaQuery.sizeOf(context).width;
    final esDialogo = ancho >= PreparacionCatalogoHost.anchoDialogo;

    Widget contenido(BuildContext c) {
      _contextoModal = c;
      return ListenableBuilder(
        listenable: _p,
        builder: (context, _) => PopScope(
          canPop: !_p.bloqueaVentas,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              esDialogo ? 24 : 16,
              esDialogo ? 24 : 20,
              esDialogo ? 24 : 16,
              (esDialogo ? 24 : 16) + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: ContenidoPreparacionCatalogo(
                estado: _p.hayQueMostrar ? _p.estado : _ultimoMostrado,
                resultado: _p.resultado,
                onPreparar: _p.preparar,
                onMasTarde: _p.posponer,
                onEmpezar: _p.cerrarListo,
              ),
            ),
          ),
        ),
      );
    }

    if (esDialogo) {
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          backgroundColor: AppColors.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.bordeMedio),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: contenido(c),
          ),
        ),
      );
    } else {
      // Sin arrastrar para cerrar: se cierra con los botones o con «atrás», y
      // mientras prepara no se cierra de ninguna forma.
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        backgroundColor: AppColors.superficie,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: contenido,
      );
    }

    _abierto = false;
    _contextoModal = null;
    // Cerrado por el vendedor (atrás o tocando fuera) sin elegir: es «Más
    // tarde»; si ya estaba listo, es «Empezar a vender».
    switch (_p.estado) {
      case EstadoPreparacion.pideConfirmar:
      case EstadoPreparacion.error:
      case EstadoPreparacion.demasiados:
        _p.posponer();
      case EstadoPreparacion.lista:
        _p.cerrarListo();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
