import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/catalogo_venta/unidad_registrada.dart';

// ═════════════════════════════════════════════════════════════════════════
// Editor de cantidad rápida (entero + unidad + fracciones de referencia)
// ═════════════════════════════════════════════════════════════════════════

class EditorCantidadRapida extends StatelessWidget {
  final List<UnidadRegistrada> unidades;
  final UnidadRegistrada referencia;
  final TextEditingController valorController;
  final UnidadRegistrada unidadSeleccionada;
  final ValueChanged<UnidadRegistrada?> onUnidadCambio;
  final VoidCallback onValorCambio;
  final VoidCallback onAgregar;
  final ValueChanged<int> onFraccion;

  const EditorCantidadRapida({
    super.key,
    required this.unidades,
    required this.referencia,
    required this.valorController,
    required this.unidadSeleccionada,
    required this.onUnidadCambio,
    required this.onValorCambio,
    required this.onAgregar,
    required this.onFraccion,
  });

  @override
  Widget build(BuildContext context) {
    final campoValor = TextField(
      key: const Key('campo-valor-rapida'),
      controller: valorController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.texto),
      decoration: const InputDecoration(
        labelText: 'Cantidad',
        hintText: 'Ej: 250',
      ),
      onChanged: (_) => onValorCambio(),
    );
    final campoUnidad = InputDecorator(
      key: const Key('campo-unidad-rapida'),
      decoration: const InputDecoration(labelText: 'Unidad'),
      child: DropdownButton<UnidadRegistrada>(
        value: unidadSeleccionada,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        selectedItemBuilder: (context) => [
          for (final unidad in unidades)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                unidad.nombre,
                style: const TextStyle(color: AppColors.texto, fontSize: 16),
              ),
            ),
        ],
        items: [
          for (final unidad in unidades)
            DropdownMenuItem(
              value: unidad,
              child: Text(
                unidad.nombre,
                style: const TextStyle(color: AppColors.texto, fontSize: 16),
              ),
            ),
        ],
        onChanged: onUnidadCambio,
      ),
    );
    final botonAgregar = IconButton.filledTonal(
      key: const Key('boton-agregar-rapida'),
      tooltip: 'Agregar cantidad rápida',
      onPressed: onAgregar,
      icon: const Icon(Icons.add),
    );

    final fracciones = referencia.factorBase % 4 == 0
        ? [
            _BotonFraccion(
              clave: 'boton-fraccion-rapida-1',
              etiqueta: '1/4',
              onTap: () => onFraccion(1),
            ),
            _BotonFraccion(
              clave: 'boton-fraccion-rapida-2',
              etiqueta: '1/2',
              onTap: () => onFraccion(2),
            ),
            _BotonFraccion(
              clave: 'boton-fraccion-rapida-3',
              etiqueta: '3/4',
              onTap: () => onFraccion(3),
            ),
            _BotonFraccion(
              clave: 'boton-fraccion-rapida-4',
              etiqueta: '1',
              onTap: () => onFraccion(4),
            ),
          ]
        : const <Widget>[];

    final filaEntrada = MediaQuery.sizeOf(context).width >= 520
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: campoValor),
              const SizedBox(width: 10),
              Expanded(child: campoUnidad),
              const SizedBox(width: 8),
              botonAgregar,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              campoValor,
              const SizedBox(height: 10),
              campoUnidad,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: botonAgregar),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filaEntrada,
        if (fracciones.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Rápida de referencia (${referencia.nombre}):',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: fracciones),
        ],
      ],
    );
  }
}

class _BotonFraccion extends StatelessWidget {
  final String clave;
  final String etiqueta;
  final VoidCallback onTap;

  const _BotonFraccion({
    required this.clave,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: Key(clave),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: AppColors.blueLt,
      ),
      child: Text(
        etiqueta,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
