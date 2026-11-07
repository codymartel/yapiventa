import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/sugerencias_caja.dart';
import '../../application/services/textos_producto_caja.dart';
import '../providers/catalogo_caja_provider.dart';

/// El buscador de Caja (maqueta B1): una cápsula de 48 px. Al tocarla aparece
/// «Cancelar» y, mientras se escribe, sugerencias de lo YA cargado (cero
/// lecturas); tocar una la elige. La consulta real espera la pausa y los 2
/// letras mínimas del provider.
class BuscadorCaja extends StatefulWidget {
  const BuscadorCaja({
    super.key,
    required this.provider,
    required this.onElegirSugerencia,
  });

  final CatalogoCajaProvider provider;

  /// El cajero tocó una sugerencia: se abre ese producto.
  final ValueChanged<Producto> onElegirSugerencia;

  @override
  State<BuscadorCaja> createState() => _BuscadorCajaState();
}

class _BuscadorCajaState extends State<BuscadorCaja> {
  late final TextEditingController _controlador;
  final FocusNode _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.provider.texto);
    _foco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _cancelar() {
    _controlador.clear();
    widget.provider.limpiarBusqueda();
    _foco.unfocus();
  }

  void _borrar() {
    _controlador.clear();
    widget.provider.limpiarBusqueda();
  }

  void _elegir(Producto p) {
    _foco.unfocus();
    widget.onElegirSugerencia(p);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.provider, _controlador]),
      builder: (context, _) {
        final sugerencias = _foco.hasFocus
            ? SugerenciasCaja.de(widget.provider.productos, _controlador.text)
            : const <Producto>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _foco.hasFocus
                            ? AppColors.blueLt
                            : AppColors.bordeMedio,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.hint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controlador,
                            focusNode: _foco,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(
                              color: AppColors.texto,
                              fontSize: 15,
                            ),
                            cursorColor: AppColors.azulTexto,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Buscar producto',
                              hintStyle: TextStyle(color: AppColors.hint),
                            ),
                            onChanged: widget.provider.escribir,
                          ),
                        ),
                        if (_controlador.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Borrar búsqueda',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.muted,
                            ),
                            onPressed: _borrar,
                          ),
                      ],
                    ),
                  ),
                ),
                if (_foco.hasFocus)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: AppColors.azulTexto,
                    ),
                    onPressed: _cancelar,
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
            if (sugerencias.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bordeMedio),
                ),
                child: Column(
                  children: [
                    for (final p in sugerencias)
                      InkWell(
                        onTap: () => _elegir(p),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.texto,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (TextosProductoCaja.tipo(p).isNotEmpty)
                                Text(
                                  TextosProductoCaja.tipo(p),
                                  style: const TextStyle(
                                    color: AppColors.hint,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
