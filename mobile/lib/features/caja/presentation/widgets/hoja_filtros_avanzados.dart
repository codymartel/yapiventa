import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/catalogo_caja_provider.dart';

/// Abre los filtros avanzados: hoja desde abajo en celular (menos de 900 px) y
/// diálogo en PC. Solo lo que no cabe en los filtros rápidos: una categoría y
/// «Solo con stock» (el orden está en su menú). Cada cambio se aplica al
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
  if (MediaQuery.sizeOf(context).width >= 900) {
    return showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.superficie,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: contenido,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => contenido,
  );
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
                    _Opcion(
                      etiqueta: 'Todas',
                      activa: provider.categoria == null,
                      onTap: () => provider.cambiarCategoria(null),
                    ),
                    for (final c in unicas)
                      _Opcion(
                        etiqueta: c,
                        activa: provider.categoria == c,
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

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.etiqueta,
    required this.activa,
    required this.onTap,
  });

  final String etiqueta;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: activa ? AppColors.blueLt.withValues(alpha: 0.22) : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activa ? AppColors.blueLt : AppColors.bordeMedio,
            ),
          ),
          child: Text(
            etiqueta,
            style: TextStyle(
              color: activa ? AppColors.azulTexto : AppColors.muted,
              fontSize: 13,
              fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
