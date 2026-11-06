import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/enlace_whatsapp.dart';
import '../../application/services/transiciones_pedido.dart';
import '../../domain/models/estado_pedido.dart';
import '../../domain/models/pedido.dart';
import '../../pedidos_dependencies.dart';
import '../providers/pedidos_provider.dart';
import 'aviso_conexion_pedidos.dart';
import 'detalle_pedido.dart';
import 'detalle_vivo_pedido.dart';
import 'dialogo_cancelar_pedido.dart';
import 'dialogo_entregar_pedido.dart';
import 'filtros_pedidos.dart';
import 'historial_pedidos_vista.dart';
import 'pedidos_vista_pc.dart';
import 'pedidos_vista_tv.dart';
import 'tarjeta_pedido.dart';
import 'textos_pestanas_pedidos.dart';

/// Abre un enlace afuera de la app (WhatsApp). Se puede cambiar en pruebas.
typedef AbrirEnlace = Future<bool> Function(Uri uri);

Future<bool> _abrirEnlaceReal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// La pantalla de pedidos del vendedor, en dos formas según el ancho:
///   - menos de 600 px (celular vertical): la lista y el detalle en una hoja
///     desde abajo;
///   - 600 px o más: lista y detalle lado a lado (tableta o celular
///     horizontal) o, en tableta vertical, la lista con un panel lateral.
/// En PC (1 100 px o más) usa `PedidosVistaPc`: tabla, números del día y
/// detalle completo. En TV (1 600 px o más) usa
/// `PedidosVistaTv`: una pantalla densa para el control remoto.
///
/// Los listeners se pausan si la pestaña o la app lleva más de
/// [tiempoParaPausar] oculta (la web no guarda caché: volver a abrirlos
/// vuelve a leer, así que no se pausa por un cambio rápido de pestaña).
class PedidosFlow extends StatefulWidget {
  const PedidosFlow({
    super.key,
    required this.negocioId,
    required this.dependencias,
    this.pais,
    this.reloj,
    this.abrirEnlace = _abrirEnlaceReal,
    this.tiempoParaPausar = const Duration(minutes: 2),
  });

  final String negocioId;
  final PedidosDependencies dependencias;

  /// País del negocio (prefijo del teléfono del cliente). null = Perú.
  final PaisTelefono? pais;
  final DateTime Function()? reloj;
  final AbrirEnlace abrirEnlace;
  final Duration tiempoParaPausar;

  @override
  State<PedidosFlow> createState() => _PedidosFlowState();
}

class _PedidosFlowState extends State<PedidosFlow> with WidgetsBindingObserver {
  /// Celular y tableta: 4 pestañas (PC agrega «Todos»).
  static const _pestanasCompactas = [
    PestanaPedidos.nuevos,
    PestanaPedidos.activos,
    PestanaPedidos.porCobrar,
    PestanaPedidos.reembolsos,
  ];

  static const double _anchoLista = 340;
  static const double _anchoPanel = 440;

  late final PedidosProvider _provider;
  late final DateTime Function() _reloj;
  Timer? _pausa;
  Timer? _relojUi;
  String? _seleccionadoId;

  @override
  void initState() {
    super.initState();
    _reloj = widget.reloj ?? DateTime.now;
    _provider = widget.dependencias.crearProvider(
      widget.negocioId,
      reloj: _reloj,
    )..iniciar();
    WidgetsBinding.instance.addObserver(this);
    // Cada minuto se redibuja para que «hace 4 min» no quede viejo.
    _relojUi = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _provider.revisarDia();
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pausa?.cancel();
    _relojUi?.cancel();
    _provider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pausa?.cancel();
      _pausa = null;
      _provider.reanudar();
    } else {
      _pausa ??= Timer(widget.tiempoParaPausar, _provider.pausar);
    }
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  void _avisar(ResultadoAccion r) {
    if (!r.hizoAlgo || r.mensaje.isEmpty || !mounted) return;
    final color = switch (r.tipo) {
      TipoResultado.error => AppColors.error,
      TipoResultado.aviso => AppColors.aviso,
      _ => AppColors.ok,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.superficie,
          content: Text(r.mensaje, style: TextStyle(color: color)),
        ),
      );
  }

  Future<void> _principal(Pedido pedido) async {
    if (pedido.estado == EstadoPedido.nuevo) {
      _avisar(await _provider.confirmar(pedido));
      return;
    }
    final siguiente = TransicionesPedido.siguiente(
      pedido.estado,
      pedido.tipoEntrega,
    );
    var cobrado = false;
    if (siguiente == EstadoPedido.entregado) {
      final respuesta = await mostrarDialogoEntregarPedido(context, pedido);
      if (respuesta == null) return;
      cobrado = respuesta && pedido.estadoPago == EstadoPago.pendiente;
    }
    _avisar(await _provider.avanzar(pedido, cobrado: cobrado));
  }

  Future<void> _cancelar(Pedido pedido) async {
    if (!await mostrarDialogoCancelarPedido(context, pedido)) return;
    _avisar(await _provider.cancelar(pedido));
  }

  Future<void> _cancelarVencidos() async {
    final cantidad = _provider.vencidosCargados;
    if (!await mostrarDialogoCancelarVencidos(context, cantidad)) return;
    _avisar(await _provider.cancelarVencidos());
  }

  Future<void> _confirmarSeleccionados() async {
    _avisar(await _provider.confirmarSeleccionados());
  }

  Future<void> _whatsapp(Pedido pedido) async {
    final nombre = pedido.cliente.nombre.trim();
    final url = EnlaceWhatsapp.construir(
      pedido.cliente.telefono,
      pais: widget.pais,
      mensaje:
          'Hola${nombre.isEmpty ? '' : ' $nombre'}, te escribo por tu pedido '
          '${pedido.clave}.',
    );
    if (url == null) return;
    final abrio = await widget.abrirEnlace(url);
    if (!abrio) {
      _avisar(
        const ResultadoAccion(
          TipoResultado.error,
          'No se pudo abrir WhatsApp.',
        ),
      );
    }
  }

  AccionesDetallePedido _acciones(Pedido p) {
    final tieneTelefono =
        EnlaceWhatsapp.construir(p.cliente.telefono, pais: widget.pais) != null;
    return AccionesDetallePedido(
      onPrincipal: () => _principal(p),
      onCancelar: () => _cancelar(p),
      onMarcarCobrado: () async =>
          _avisar(await _provider.marcarPago(p, EstadoPago.pagado)),
      onReembolso: () async => _avisar(await _provider.marcarReembolsoHecho(p)),
      onWhatsapp: tieneTelefono ? () => _whatsapp(p) : null,
    );
  }

  void _abrirHistorial() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistorialPedidosVista(
          provider: widget.dependencias.crearHistorial(widget.negocioId),
          reloj: _reloj,
        ),
      ),
    );
  }

  // ── Detalle ───────────────────────────────────────────────────────────

  void _seleccionar(Pedido pedido, {required bool enHoja}) {
    if (!enHoja) {
      setState(() => _seleccionadoId = pedido.id);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (hojaContext) => ChangeNotifierProvider.value(
        value: _provider,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: DetalleVivoPedido(
            pedidoId: pedido.id,
            reloj: _reloj,
            acciones: _acciones,
            onVacio: () => Navigator.of(hojaContext).maybePop(),
          ),
        ),
      ),
    );
  }

  // ── Construcción ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth;
          if (ancho >= 1600) {
            return PedidosVistaTv(reloj: _reloj, acciones: _acciones);
          }
          if (ancho >= 1100) {
            return PedidosVistaPc(
              reloj: _reloj,
              seleccionadoId: _seleccionadoId,
              onSeleccionar: (p) => setState(() => _seleccionadoId = p.id),
              onCerrarDetalle: () => setState(() => _seleccionadoId = null),
              acciones: _acciones,
              onHistorial: _abrirHistorial,
              onCancelarVencidos: _cancelarVencidos,
              onConfirmarSeleccionados: _confirmarSeleccionados,
            );
          }
          if (ancho < 600) {
            return _lista(enHoja: true);
          }
          final vertical = c.maxHeight >= ancho;
          final detalle = _seleccionadoId == null
              ? null
              : DetalleVivoPedido(
                  pedidoId: _seleccionadoId!,
                  reloj: _reloj,
                  acciones: _acciones,
                  onVacio: () => setState(() => _seleccionadoId = null),
                );
          if (vertical) {
            return Stack(
              children: [
                _lista(enHoja: false),
                if (detalle != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: _anchoPanel.clamp(0, ancho * 0.9),
                    child: _Panel(
                      onCerrar: () => setState(() => _seleccionadoId = null),
                      hijo: detalle,
                    ),
                  ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: _anchoLista, child: _lista(enHoja: false)),
              const VerticalDivider(width: 1, color: AppColors.dim),
              Expanded(
                child:
                    detalle ??
                    const Center(
                      child: Text(
                        'Elige un pedido para ver el detalle.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _lista({required bool enHoja}) {
    return Consumer<PedidosProvider>(
      builder: (context, p, _) {
        final ahora = _reloj();
        final pestana = p.pestana;
        final pedidos = p.pedidosActuales;
        return Column(
          children: [
            FiltrosPedidos(
              pestana: pestana,
              pestanas: _pestanasCompactas,
              etiquetaPestana: (t) => etiquetaDePestana(p, t),
              conteoNuevos: p.conteo(PestanaPedidos.nuevos),
              conteoActivos: p.conteo(PestanaPedidos.activos),
              porCobrarCentavos: p.porCobrarCentavos,
              porCobrarExacto: p.porCobrarEsExacto,
              vencidos: p.vencidosCargados,
              cancelandoVencidos: p.cancelandoVencidos,
              onPestana: p.seleccionarPestana,
              onHistorial: _abrirHistorial,
              onCancelarVencidos: _cancelarVencidos,
            ),
            if (p.error != null)
              AvisoConexionPedidos(
                mensaje: p.error!,
                onReintentar: p.reintentar,
              ),
            Expanded(
              child: p.cargando(pestana) && pedidos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : pedidos.isEmpty
                  ? Center(
                      child: Text(
                        textoVacioDePestana(pestana),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => p.reiniciarPaginas(pestana),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: pedidos.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          if (i == pedidos.length) {
                            return _VerMas(provider: p, pestana: pestana);
                          }
                          final pedido = pedidos[i];
                          return TarjetaPedido(
                            pedido: pedido,
                            ahora: ahora,
                            vencido: TransicionesPedido.estaVencido(
                              pedido,
                              ahora,
                            ),
                            seleccionado: pedido.id == _seleccionadoId,
                            onTap: () => _seleccionar(pedido, enHoja: enHoja),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _VerMas extends StatelessWidget {
  const _VerMas({required this.provider, required this.pestana});

  final PedidosProvider provider;
  final PestanaPedidos pestana;

  @override
  Widget build(BuildContext context) {
    if (provider.cargandoMas(pestana)) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!provider.hayMas(pestana)) return const SizedBox.shrink();
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      onPressed: () async {
        final r = await provider.verMas(pestana);
        if (r.fallo && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(r.mensaje)));
        }
      },
      child: const Text('Ver más'),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.onCerrar, required this.hijo});

  final VoidCallback onCerrar;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      elevation: 8,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Cerrar detalle',
              onPressed: onCerrar,
              icon: const Icon(Icons.close, color: AppColors.muted),
            ),
          ),
          Expanded(child: hijo),
        ],
      ),
    );
  }
}
