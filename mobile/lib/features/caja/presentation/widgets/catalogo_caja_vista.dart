import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/catalogo_caja_provider.dart';
import 'botones_caja.dart';
import 'buscador_caja.dart';
import 'filtros_caja.dart';
import 'tarjeta_producto_caja.dart';

/// El catálogo de Caja (maqueta B1): buscador, filtros y la lista de 20 en 20
/// con «Ver más». Arriba queda fijo lo que se usa seguido (buscar y filtrar);
/// solo la lista se desplaza. Estados: cargando, vacío (según lo que se pidió),
/// error con «Reintentar» y «Ver más» que también puede fallar sin perder lo
/// cargado.
class CatalogoCajaVista extends StatelessWidget {
  const CatalogoCajaVista({
    super.key,
    required this.provider,
    required this.rubro,
    this.categorias = const [],
    required this.onElegir,
    this.cabecera,
  });

  final CatalogoCajaProvider provider;
  final String rubro;
  final List<String> categorias;
  final ValueChanged<Producto> onElegir;

  /// Algo fijo sobre el buscador (por ejemplo, el aviso de «Preparar
  /// catálogo»).
  final Widget? cabecera;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cabecera != null) ...[cabecera!, const SizedBox(height: 8)],
        BuscadorCaja(provider: provider, onElegirSugerencia: onElegir),
        const SizedBox(height: 8),
        FiltrosCaja(provider: provider, rubro: rubro, categorias: categorias),
        const SizedBox(height: 4),
        Expanded(
          child: ListenableBuilder(
            listenable: provider,
            builder: (context, _) =>
                _Lista(provider: provider, onElegir: onElegir),
          ),
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.provider, required this.onElegir});

  final CatalogoCajaProvider provider;
  final ValueChanged<Producto> onElegir;

  @override
  Widget build(BuildContext context) {
    final productos = provider.productos;
    if (provider.cargando && productos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && productos.isEmpty) {
      return _Mensaje(
        icono: Icons.cloud_off_outlined,
        titulo: provider.error!,
        accion: 'Reintentar',
        onAccion: provider.reiniciar,
      );
    }
    if (provider.vacio) {
      return _Mensaje(icono: Icons.search_off, titulo: _textoVacio());
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: productos.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i < productos.length) {
          return TarjetaProductoCaja(
            producto: productos[i],
            onElegir: onElegir,
          );
        }
        return _Pie(provider: provider);
      },
    );
  }

  String _textoVacio() {
    if (provider.buscando) {
      return 'No encontramos «${provider.texto.trim()}». Prueba con otra '
          'palabra o quita los filtros.';
    }
    if (provider.soloConStock ||
        provider.tipo != null ||
        provider.categoria != null) {
      return 'No hay productos con estos filtros.';
    }
    return 'Todavía no tienes productos disponibles. Agrégalos en Productos.';
  }
}

class _Pie extends StatelessWidget {
  const _Pie({required this.provider});

  final CatalogoCajaProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.cargandoMas) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        if (provider.hayMas)
          BotonSecundarioCaja(texto: 'Ver más', onTap: provider.verMas),
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.titulo,
    this.accion,
    this.onAccion,
  });

  final IconData icono;
  final String titulo;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: AppColors.hint),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (accion != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: BotonPrincipalCaja(texto: accion!, onTap: onAccion),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
