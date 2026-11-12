import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/catalogo_caja_provider.dart';
import 'chip_caja.dart';
import 'hoja_caja.dart';

/// Abre los filtros avanzados: hoja desde abajo en celular y tableta (menos
/// de 1 100 px) y diálogo en PC. Solo lo que no cabe en los filtros
/// rápidos: una categoría y «Solo con stock» (el orden está en su menú). Cada cambio se aplica al
/// instante a la lista de atrás; «Listo» cierra.
Future<void> mostrarFiltrosAvanzados(
  BuildContext context, {
  required CatalogoCajaProvider provider,
  List<String> categorias = const [],
}) {
  final contenido = _ContenidoFiltros(
    provider: provider,
    categorias: categorias,
  );
  return mostrarHojaCaja<void>(context, builder: (_) => contenido);
}

class _ContenidoFiltros extends StatelessWidget {
  const _ContenidoFiltros({required this.provider, required this.categorias});

  final CatalogoCajaProvider provider;
  final List<String> categorias;

  @override
  Widget build(BuildContext context) {
    final unicas = <String>[];
    for (final c in categorias) {
      final limpia = c.trim();
      if (limpia.isNotEmpty && !unicas.contains(limpia)) unicas.add(limpia);
    }
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: AppColors.azulTexto,
                    ),
                    onPressed: () {
                      provider
                        ..cambiarCategoria(null)
                        ..cambiarSoloConStock(false);
                    },
                    child: const Text('Restablecer'),
                  ),
                  const Expanded(
                    child: Text(
                      'Filtros avanzados',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: AppColors.azulTexto,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Listo'),
                  ),
                ],
              ),
              if (unicas.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'CATEGORÍA',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChipCaja(
                      etiqueta: 'Todas',
                      activo: provider.categoria == null,
                      onTap: () => provider.cambiarCategoria(null),
                    ),
                    for (final c in unicas)
                      ChipCaja(
                        etiqueta: c,
                        activo: provider.categoria == c,
                        onTap: () => provider.cambiarCategoria(c),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Solo con stock',
                  style: TextStyle(color: AppColors.texto, fontSize: 14),
                ),
                subtitle: const Text(
                  'Oculta lo agotado de la lista cargada.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                value: provider.soloConStock,
                onChanged: provider.cambiarSoloConStock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
