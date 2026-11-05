import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/pedido.dart';
import '../providers/historial_pedidos_provider.dart';
import 'aviso_conexion_pedidos.dart';
import 'detalle_pedido.dart';
import 'tarjeta_historial_dia.dart';

/// El historial por día (entregados y cancelados). Solo se mira: no escucha
/// nada, lee 20 al abrirse y 20 por cada «Ver más».
class HistorialPedidosVista extends StatefulWidget {
  const HistorialPedidosVista({
    super.key,
    required this.provider,
    required this.reloj,
  });

  final HistorialPedidosProvider provider;
  final DateTime Function() reloj;

  @override
  State<HistorialPedidosVista> createState() => _HistorialPedidosVistaState();
}

class _HistorialPedidosVistaState extends State<HistorialPedidosVista> {
  @override
  void initState() {
    super.initState();
    widget.provider.cargar();
  }

  @override
  void dispose() {
    widget.provider.dispose();
    super.dispose();
  }

  void _abrir(Pedido pedido) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: DetallePedido(
          pedido: pedido,
          ahora: widget.reloj(),
          vencido: false,
          procesando: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.provider,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          backgroundColor: AppColors.superficie,
          foregroundColor: AppColors.texto,
          title: const Text('Historial de pedidos'),
        ),
        body: SafeArea(
          child: Consumer<HistorialPedidosProvider>(
            builder: (context, p, _) {
              if (p.cargando && !p.cargado) {
                return const Center(child: CircularProgressIndicator());
              }
              if (p.error != null && !p.cargado) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: AvisoConexionPedidos(
                    mensaje: p.error!,
                    onReintentar: p.cargar,
                  ),
                );
              }
              if (p.dias.isEmpty) {
                return const Center(
                  child: Text(
                    'Todavía no hay pedidos entregados ni cancelados.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                );
              }
              final ahora = widget.reloj();
              final dias = p.dias;
              return RefreshIndicator(
                onRefresh: p.refrescar,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (p.error != null)
                      AvisoConexionPedidos(
                        mensaje: p.error!,
                        onReintentar: p.cargarMas,
                      ),
                    for (var i = 0; i < dias.length; i++)
                      TarjetaHistorialDia(
                        resumen: dias[i],
                        ahora: ahora,
                        onAbrirPedido: _abrir,
                        incompleto:
                            i == dias.length - 1 &&
                            p.ultimoDiaPuedeEstarIncompleto,
                      ),
                    if (p.hayMas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: p.cargandoMas
                            ? const Center(child: CircularProgressIndicator())
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                onPressed: p.cargarMas,
                                child: const Text('Ver más'),
                              ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
