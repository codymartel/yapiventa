import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/consulta_catalogo_caja.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/filtros_rapidos_caja.dart';
import '../providers/catalogo_caja_provider.dart';
import 'chip_caja.dart';
import 'hoja_filtros_avanzados.dart';

/// Los filtros de la lista de Caja (maqueta B1): una fila que se desliza con
/// «Avanzados» (y cuántos hay puestos) y los filtros rápidos del rubro, y
/// debajo el menú del orden. Un toque cambia la lista al instante (lo ya
/// visto sale de la memoria: 0 lecturas).
class FiltrosCaja extends StatelessWidget {
  const FiltrosCaja({
    super.key,
    required this.provider,
    required this.rubro,
    this.categorias = const [],
  });

  final CatalogoCajaProvider provider;
  final String rubro;

  /// Las categorías propias del negocio.
  final List<String> categorias;

  static String etiquetaOrden(OrdenCatalogoCaja orden) => switch (orden) {
    OrdenCatalogoCaja.frecuentes => 'Más vendidos',
    OrdenCatalogoCaja.recientes => 'Más recientes',
    OrdenCatalogoCaja.nombre => 'Nombre (A a Z)',
  };

  @override
  Widget build(BuildContext context) {
    final rapidos = FiltrosRapidosCaja.para(
      rubro: rubro,
      categorias: categorias,
    );
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final avanzados = FiltrosRapidosCaja.avanzadosActivos(
          rapidos: rapidos,
          categoria: provider.categoria,
          soloConStock: provider.soloConStock,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChipCaja(
                    etiqueta: avanzados > 0
                        ? 'Avanzados · $avanzados'
                        : 'Avanzados',
                    icono: Icons.tune,
                    activo: avanzados > 0,
                    onTap: () => mostrarFiltrosAvanzados(
                      context,
                      provider: provider,
                      categorias: categorias,
                    ),
                  ),
                  for (final f in rapidos) ...[
                    const SizedBox(width: 8),
                    ChipCaja(
                      etiqueta: f.etiqueta,
                      activo: f.estaActivo(provider.tipo, provider.categoria),
                      onTap: () => provider.aplicarFiltro(
                        tipo: f.tipo,
                        categoria: f.categoria,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            _MenuOrden(provider: provider),
          ],
        );
      },
    );
  }
}

class _MenuOrden extends StatelessWidget {
  const _MenuOrden({required this.provider});

  final CatalogoCajaProvider provider;

  @override
  Widget build(BuildContext context) {
    final buscando = provider.buscando;
    final etiqueta = buscando
        ? 'Orden: por nombre'
        : 'Orden: ${FiltrosCaja.etiquetaOrden(provider.orden)}';
    final texto = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        if (!buscando)
          const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.muted),
      ],
    );
    if (buscando) {
      return SizedBox(
        height: 44,
        child: Align(alignment: Alignment.centerLeft, child: texto),
      );
    }
    return PopupMenuButton<OrdenCatalogoCaja>(
      tooltip: 'Cambiar el orden',
      color: AppColors.superficie,
      onSelected: provider.cambiarOrden,
      itemBuilder: (_) => [
        for (final o in OrdenCatalogoCaja.values)
          CheckedPopupMenuItem<OrdenCatalogoCaja>(
            value: o,
            checked: provider.orden == o,
            child: Text(
              FiltrosCaja.etiquetaOrden(o),
              style: const TextStyle(color: AppColors.texto),
            ),
          ),
      ],
      child: SizedBox(
        height: 44,
        child: Align(alignment: Alignment.centerLeft, child: texto),
      ),
    );
  }
}
