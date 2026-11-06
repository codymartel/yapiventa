import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/indicadores_pedidos.dart';
import '../../application/services/lista_pedidos_paginada.dart';
import '../../application/services/mensajes_accion_pedido.dart';
import '../../application/services/por_preparar_pedidos.dart';
import '../../application/services/resumen_dia_pedidos.dart';
import '../../domain/models/pedido.dart';
import '../../domain/models/resumen_ventas_dia.dart';
import '../providers/pedidos_provider.dart';
import 'detalle_pedido.dart';
import 'detalle_vivo_pedido.dart';
import 'indicadores_pc.dart';
import 'tabla_pedidos.dart';

/// La pantalla de pedidos para TV (1 600 px o más): una sola vista densa que
/// se mira de lejos y se maneja con el control remoto. Arriba la hora y los 6
/// números del día; al centro la tabla de TODOS los pedidos abiertos (con el
/// foco marcado por un borde blanco) y los últimos entregados; a la derecha lo
/// que hay que preparar y los avisos.
///
/// Control remoto: ▲ ▼ mueven el foco, OK abre el detalle (ahí se confirma o
/// avanza el pedido), Atrás cierra el detalle. Letra de 20 px o más y margen
/// seguro de 40 px. No agrega lecturas: usa lo que ya escuchan los providers.
class PedidosVistaTv extends StatefulWidget {
  const PedidosVistaTv({
    super.key,
    required this.reloj,
    required this.acciones,
  });

  final DateTime Function() reloj;
  final AccionesDetallePedido Function(Pedido) acciones;

  static const double margenSeguro = 40;
  static const double anchoPanel = 440;
  static const double escalaTabla = 1.55;
  static const double alturaFila = 84;

  @override
  State<PedidosVistaTv> createState() => _PedidosVistaTvState();
}

class _PedidosVistaTvState extends State<PedidosVistaTv> {
  final ScrollController _scroll = ScrollController();
  int _indice = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _mover(int paso, int total) {
    if (total == 0) return;
    final nuevo = (_indice + paso).clamp(0, total - 1);
    if (nuevo == _indice) return;
    setState(() => _indice = nuevo);
    _asegurarVisible(nuevo);
  }

  /// Mantiene a la vista la fila con el foco (filas de altura fija).
  void _asegurarVisible(int indice) {
    if (!_scroll.hasClients) return;
    final arriba = indice * PedidosVistaTv.alturaFila;
    final abajo = arriba + PedidosVistaTv.alturaFila;
    final visible = _scroll.position.viewportDimension;
    if (arriba < _scroll.offset) {
      _scroll.jumpTo(arriba);
    } else if (abajo > _scroll.offset + visible) {
      _scroll.jumpTo(abajo - visible);
    }
  }

  void _abrir(Pedido pedido) {
    final provider = context.read<PedidosProvider>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ChangeNotifierProvider.value(
        value: provider,
        child: Dialog(
          backgroundColor: AppColors.superficie,
          insetPadding: const EdgeInsets.all(PedidosVistaTv.margenSeguro),
          child: SizedBox(
            width: 820,
            height: 760,
            // El detalle se lee de lejos: letra más grande.
            child: MediaQuery(
              data: MediaQuery.of(
                dialogContext,
              ).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: DetalleVivoPedido(
                pedidoId: pedido.id,
                reloj: widget.reloj,
                acciones: widget.acciones,
                onVacio: () => Navigator.of(dialogContext).maybePop(),
                completo: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _tecla(KeyEvent evento, List<Pedido> pedidos) {
    if (evento is! KeyDownEvent && evento is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final tecla = evento.logicalKey;
    if (tecla == LogicalKeyboardKey.arrowDown) {
      _mover(1, pedidos.length);
      return KeyEventResult.handled;
    }
    if (tecla == LogicalKeyboardKey.arrowUp) {
      _mover(-1, pedidos.length);
      return KeyEventResult.handled;
    }
    if (tecla == LogicalKeyboardKey.enter ||
        tecla == LogicalKeyboardKey.numpadEnter ||
        tecla == LogicalKeyboardKey.select ||
        tecla == LogicalKeyboardKey.gameButtonA) {
      if (pedidos.isNotEmpty) {
        _abrir(pedidos[_indice.clamp(0, pedidos.length - 1)]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PedidosProvider>(
      builder: (context, p, _) {
        final ahora = widget.reloj();
        final pedidos = ListaPedidosPaginada.unirPorFecha([
          p.pedidosDe(PestanaPedidos.nuevos),
          p.pedidosDe(PestanaPedidos.activos),
        ]);
        final indice = pedidos.isEmpty
            ? 0
            : _indice.clamp(0, pedidos.length - 1);
        final indicadores = p.indicadores;
        return Focus(
          autofocus: true,
          onKeyEvent: (_, evento) => _tecla(evento, pedidos),
          child: Container(
            color: AppColors.fondo,
            child: Column(
              children: [
                _Cabecera(
                  hora: ResumenDiaPedidos.horaLima(ahora),
                  nuevos: indicadores.nuevos,
                  enVivo: !p.pausado,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PedidosVistaTv.margenSeguro,
                    vertical: 8,
                  ),
                  child: IndicadoresPc(
                    escala: 1.8,
                    indicadores: indicadores,
                    conteoNuevos: p.conteo(PestanaPedidos.nuevos),
                    conteoActivos: p.conteo(PestanaPedidos.activos),
                    resumen: p.resumenHoy,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PedidosVistaTv.margenSeguro,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: pedidos.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No hay pedidos abiertos.',
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 24,
                                          ),
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        controller: _scroll,
                                        child: TablaPedidos(
                                          pedidos: pedidos,
                                          ahora: ahora,
                                          seleccionadoId: null,
                                          focoId: pedidos[indice].id,
                                          escala: PedidosVistaTv.escalaTabla,
                                          alturaFila: PedidosVistaTv.alturaFila,
                                          anchoMinimoProductos: 1150,
                                          onAbrir: _abrir,
                                        ),
                                      ),
                              ),
                              _UltimosEntregados(resumen: p.resumenHoy),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: PedidosVistaTv.anchoPanel,
                          child: _PanelLateral(
                            porPreparar: p.porPreparar,
                            indicadores: indicadores,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const _Ayuda(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.hora,
    required this.nuevos,
    required this.enVivo,
  });

  final String hora;
  final int nuevos;
  final bool enVivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(
        horizontal: PedidosVistaTv.margenSeguro,
      ),
      color: AppColors.superficie,
      child: Row(
        children: [
          const Text(
            'YapiVenta · Pedidos',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 20),
          if (nuevos > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.aviso,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                nuevos == 1 ? '1 nuevo' : '$nuevos nuevos',
                style: const TextStyle(
                  color: Color(0xFF201800),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const Spacer(),
          Text(
            hora,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 20),
          Text(
            enVivo ? '● En vivo' : '● En pausa',
            style: TextStyle(
              color: enVivo ? AppColors.ok : AppColors.muted,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.hijos, this.color});

  final String titulo;
  final List<Widget> hijos;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color ?? AppColors.bordeSutil),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: color ?? AppColors.texto,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          ...hijos,
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.izquierda, [this.derecha]);

  final String izquierda;
  final String? derecha;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              izquierda,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 20),
            ),
          ),
          if (derecha != null)
            Text(
              derecha!,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _UltimosEntregados extends StatelessWidget {
  const _UltimosEntregados({required this.resumen});

  final ResumenVentasDia resumen;

  @override
  Widget build(BuildContext context) {
    final entregados = resumen.ultimosEntregados;
    return _Bloque(
      titulo: 'Últimos entregados hoy',
      hijos: [
        if (entregados.isEmpty)
          const _Linea('Todavía no se entregó ningún pedido hoy.')
        else
          for (final e in entregados)
            _Linea(
              [
                if (e.hora != null) ResumenDiaPedidos.horaLima(e.hora!),
                e.cliente,
                e.productos,
              ].where((t) => t.isNotEmpty).join(' · '),
              '${e.metodoPago.isEmpty ? '' : '${e.metodoPago} · '}'
              '${e.cobrado ? 'pagado' : 'sin cobrar'} · '
              '${MensajesAccionPedido.dinero(e.totalCentavos)}',
            ),
      ],
    );
  }
}

class _PanelLateral extends StatelessWidget {
  const _PanelLateral({required this.porPreparar, required this.indicadores});

  final List<ItemPorPreparar> porPreparar;
  final IndicadoresPedidos indicadores;

  @override
  Widget build(BuildContext context) {
    final avisos = <String>[
      if (indicadores.vencidos > 0)
        indicadores.vencidos == 1
            ? '1 pedido vencido (+12 h)'
            : '${indicadores.vencidos} pedidos vencidos (+12 h)',
      if (indicadores.porCobrarPedidos > 0)
        indicadores.porCobrarPedidos == 1
            ? '1 pedido sin cobrar'
            : '${indicadores.porCobrarPedidos} pedidos sin cobrar',
    ];
    return SingleChildScrollView(
      child: Column(
        children: [
          _Bloque(
            titulo: 'Por preparar ahora',
            hijos: [
              if (porPreparar.isEmpty)
                const _Linea('Nada por preparar.')
              else
                for (final item in porPreparar)
                  _Linea(item.nombre, item.cantidadTexto),
            ],
          ),
          _Bloque(
            titulo: 'Atención',
            color: indicadores.vencidos > 0 ? AppColors.error : null,
            hijos: [
              if (avisos.isEmpty)
                const _Linea('Todo en orden.')
              else
                for (final aviso in avisos) _Linea('⚠ $aviso'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Ayuda extends StatelessWidget {
  const _Ayuda();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(color: AppColors.muted, fontSize: 20);
    const tecla = TextStyle(
      color: AppColors.texto,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );
    Widget par(String t, String texto) => Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$t  ', style: tecla),
            TextSpan(text: texto, style: estilo),
          ],
        ),
      ),
    );
    return Container(
      height: 64,
      color: AppColors.superficie,
      padding: const EdgeInsets.symmetric(
        horizontal: PedidosVistaTv.margenSeguro,
      ),
      child: Row(
        children: [
          par('▲ ▼', 'mover'),
          par('OK', 'abrir el pedido y su siguiente paso'),
          par('Atrás', 'volver'),
        ],
      ),
    );
  }
}
