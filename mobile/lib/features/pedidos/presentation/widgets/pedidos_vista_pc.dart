import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/pedido.dart';
import '../providers/pedidos_provider.dart';
import 'aviso_conexion_pedidos.dart';
import 'detalle_pedido.dart';
import 'detalle_vivo_pedido.dart';
import 'filtros_pedidos.dart';
import 'indicadores_pc.dart';
import 'por_preparar_vista.dart';
import 'tabla_pedidos.dart';

/// La pantalla de pedidos para PC (1 100 px o más): búsqueda, los 6 números
/// del día, pestañas, acciones en lote, la tabla con todos los datos, «por
/// preparar» y, a la derecha, el detalle completo del pedido elegido.
///
/// Solo arma lo que se ve: el estado vive en `PedidosProvider` y las acciones
/// las hace `PedidosFlow`, que le pasa los callbacks.
class PedidosVistaPc extends StatelessWidget {
  const PedidosVistaPc({
    super.key,
    required this.reloj,
    required this.seleccionadoId,
    required this.onSeleccionar,
    required this.onCerrarDetalle,
    required this.acciones,
    required this.onHistorial,
    required this.onCancelarVencidos,
    required this.onConfirmarSeleccionados,
  });

  static const double anchoDetalle = 420;

  final DateTime Function() reloj;
  final String? seleccionadoId;
  final ValueChanged<Pedido> onSeleccionar;
  final VoidCallback onCerrarDetalle;
  final AccionesDetallePedido Function(Pedido) acciones;
  final VoidCallback onHistorial;
  final VoidCallback onCancelarVencidos;
  final VoidCallback onConfirmarSeleccionados;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Izquierda(vista: this)),
        VerticalDivider(width: 1, color: AppColors.bordeSutil),
        SizedBox(
          width: anchoDetalle,
          child: seleccionadoId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Elige un pedido para ver el detalle completo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              : DetalleVivoPedido(
                  key: ValueKey(seleccionadoId),
                  pedidoId: seleccionadoId!,
                  reloj: reloj,
                  acciones: acciones,
                  onVacio: onCerrarDetalle,
                  completo: true,
                ),
        ),
      ],
    );
  }
}

class _Izquierda extends StatelessWidget {
  const _Izquierda({required this.vista});

  final PedidosVistaPc vista;

  @override
  Widget build(BuildContext context) {
    return Consumer<PedidosProvider>(
      builder: (context, p, _) {
        final ahora = vista.reloj();
        final pestana = p.pestana;
        final pedidos = p.pedidosFiltrados;
        final sinFiltro = p.pedidosActuales;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _CampoBusqueda(
                        inicial: p.busqueda,
                        onCambio: p.actualizarBusqueda,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    p.pausado ? '● En pausa' : '● En vivo',
                    style: TextStyle(
                      color: p.pausado ? AppColors.muted : AppColors.ok,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: IndicadoresPc(
                indicadores: p.indicadores,
                conteoNuevos: p.conteo(PestanaPedidos.nuevos),
                conteoActivos: p.conteo(PestanaPedidos.activos),
                resumen: p.resumenHoy,
              ),
            ),
            FiltrosPedidos(
              mostrarNumeros: false,
              pestana: pestana,
              conteoNuevos: p.conteo(PestanaPedidos.nuevos),
              conteoActivos: p.conteo(PestanaPedidos.activos),
              porCobrarCentavos: p.porCobrarCargadoCentavos,
              vencidos: p.vencidosCargados,
              cancelandoVencidos: p.cancelandoVencidos,
              onPestana: p.seleccionarPestana,
              onHistorial: vista.onHistorial,
              onCancelarVencidos: vista.onCancelarVencidos,
            ),
            if (p.error != null)
              AvisoConexionPedidos(
                mensaje: p.error!,
                onReintentar: p.reintentar,
              ),
            if (pestana == PestanaPedidos.nuevos)
              _BarraLote(
                cantidad: p.seleccionados.length,
                ocupado: p.cancelandoVencidos,
                onConfirmar: vista.onConfirmarSeleccionados,
                onLimpiar: p.limpiarSeleccion,
              ),
            Expanded(
              child: pedidos.isEmpty
                  ? _Vacio(
                      cargando: p.cargando(pestana) && sinFiltro.isEmpty,
                      mensaje: p.busqueda.trim().isNotEmpty
                          ? 'Sin resultados entre los pedidos cargados.'
                          : pestana == PestanaPedidos.nuevos
                          ? 'No hay pedidos nuevos.'
                          : 'No hay pedidos activos.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        TablaPedidos(
                          pedidos: pedidos,
                          ahora: ahora,
                          seleccionadoId: vista.seleccionadoId,
                          marcados: p.seleccionados,
                          conCasillas: pestana == PestanaPedidos.nuevos,
                          onAbrir: vista.onSeleccionar,
                          onAlternar: p.alternarSeleccion,
                          onMarcarTodos: p.seleccionarVisibles,
                        ),
                        _VerMas(provider: p, pestana: pestana),
                        const SizedBox(height: 12),
                        PorPrepararVista(items: p.porPreparar),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.cargando, required this.mensaje});

  final bool cargando;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    if (cargando) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Text(mensaje, style: const TextStyle(color: AppColors.muted)),
    );
  }
}

class _BarraLote extends StatelessWidget {
  const _BarraLote({
    required this.cantidad,
    required this.ocupado,
    required this.onConfirmar,
    required this.onLimpiar,
  });

  final int cantidad;
  final bool ocupado;
  final VoidCallback onConfirmar;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            cantidad == 1 ? '1 seleccionado' : '$cantidad seleccionados',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(44, 40)),
            onPressed: cantidad == 0 || ocupado ? null : onConfirmar,
            child: const Text('Confirmar seleccionados'),
          ),
          if (cantidad > 0)
            TextButton(
              onPressed: onLimpiar,
              child: const Text('Quitar marcas'),
            ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
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
      ),
    );
  }
}

/// Busca entre los pedidos ya cargados (por clave, cliente o teléfono).
class _CampoBusqueda extends StatefulWidget {
  const _CampoBusqueda({required this.inicial, required this.onCambio});

  final String inicial;
  final ValueChanged<String> onCambio;

  @override
  State<_CampoBusqueda> createState() => _CampoBusquedaState();
}

class _CampoBusquedaState extends State<_CampoBusqueda> {
  late final TextEditingController _controlador = TextEditingController(
    text: widget.inicial,
  );

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controlador,
      onChanged: widget.onCambio,
      style: const TextStyle(color: AppColors.texto),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar clave, cliente o teléfono (entre los cargados)',
        hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AppColors.bordeSutil),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AppColors.bordeSutil),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
