import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../application/services/calculo_combo.dart';
import '../../../application/services/entrada_numerica.dart';
import '../../providers/formulario_combo_controller.dart';
import 'formato_entradas.dart';
import 'miniatura_parte.dart';
import 'selector_parte_combo.dart';

/// «¿Es un combo?» y, con «Sí», lo que incluye, su precio y su stock
/// calculado. La palabra cambia según el rubro («kit», «conjunto»…). El combo
/// no tiene stock propio: se calcula de los productos que lo forman.
///
/// Con menos de 2 productos para elegir no hay combo posible y la pregunta no
/// se muestra (salvo que el producto ya sea un combo).
class SeccionComboProducto extends StatelessWidget {
  const SeccionComboProducto({super.key, required this.combo});

  final FormularioComboController combo;

  @override
  Widget build(BuildContext context) {
    if (!combo.usa && combo.elegibles.length < 2) {
      return const SizedBox.shrink();
    }
    final palabra = combo.nombre.palabra;
    return Container(
      key: const Key('pregunta-combo'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeMedio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(text: '¿Es un $palabra? '),
                TextSpan(
                  text: 'varios productos juntos',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            key: const Key('segmento-combo'),
            segments: const [
              ButtonSegment(value: true, label: Text('Sí')),
              ButtonSegment(value: false, label: Text('No')),
            ],
            selected: {combo.usa},
            showSelectedIcon: false,
            onSelectionChanged: (seleccion) => combo.activar(seleccion.first),
          ),
          if (combo.usa) _Detalle(combo: combo),
        ],
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.combo});

  final FormularioComboController combo;

  @override
  Widget build(BuildContext context) {
    final resultado = combo.resultado;
    final palabra = combo.nombre.palabra;
    final ahorro = combo.ahorroCentavos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Text(
          'Qué incluye · ${combo.partes.length} '
          '${combo.partes.length == 1 ? 'producto' : 'productos'}',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        for (var i = 0; i < combo.partes.length; i++)
          _FilaParte(combo: combo, indice: i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('agregar-parte-combo'),
            onPressed: combo.puedeAgregar
                ? () => abrirSelectorPartes(context, combo)
                : null,
            child: const Text(
              '+ Agregar producto',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
        if (combo.partes.isNotEmpty && resultado.sumaCentavos != null)
          Text(
            'Suma de las partes: S/ ${centavosATexto(resultado.sumaCentavos!)}',
            key: const Key('suma-partes'),
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        TextField(
          key: const Key('precio-combo'),
          controller: combo.precioCtrl,
          onChanged: (_) => combo.trasCambioPrecio(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [FormatoPrecio()],
          style: TextStyle(color: AppColors.texto),
          decoration: InputDecoration(labelText: 'Precio del $palabra S/ *'),
        ),
        if (ahorro != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'El cliente ahorra S/ ${centavosATexto(ahorro)}',
              key: const Key('ahorro-combo'),
              style: TextStyle(color: AppColors.ok, fontSize: 13),
            ),
          ),
        if (combo.partes.isNotEmpty && resultado.sumaCentavos != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('usar-la-suma'),
              onPressed: combo.usarLaSuma,
              child: const Text('Usar la suma', style: TextStyle(fontSize: 13)),
            ),
          ),
        if (combo.avisoPartesCambiaron != null)
          Text(
            combo.avisoPartesCambiaron!,
            key: const Key('aviso-partes-cambiaron'),
            style: TextStyle(
              color: AppColors.aviso,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 8),
        _StockCalculado(resultado: resultado),
      ],
    );
  }
}

class _FilaParte extends StatelessWidget {
  const _FilaParte({required this.combo, required this.indice});

  final FormularioComboController combo;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final parte = combo.partes[indice];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.dim)),
      ),
      child: Row(
        children: [
          MiniaturaParte(url: parte.urlImagen),
          Expanded(
            child: Text(
              parte.nombre.isEmpty ? 'Producto' : parte.nombre,
              style: TextStyle(color: AppColors.texto, fontSize: 14),
            ),
          ),
          IconButton(
            key: Key('menos-parte-$indice'),
            tooltip: 'Quitar uno',
            onPressed: parte.cantidad > 1
                ? () => combo.cambiarCantidad(indice, -1)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '${parte.cantidad}',
            key: Key('cantidad-parte-$indice'),
            style: TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            key: Key('mas-parte-$indice'),
            tooltip: 'Agregar uno',
            onPressed: () => combo.cambiarCantidad(indice, 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            key: Key('quitar-parte-$indice'),
            tooltip: 'Quitar del combo',
            onPressed: () => combo.quitar(indice),
            icon: Icon(Icons.close, size: 18, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// El stock del combo, calculado de las partes (con candado: no se escribe).
class _StockCalculado extends StatelessWidget {
  const _StockCalculado({required this.resultado});

  final ResultadoCombo resultado;

  @override
  Widget build(BuildContext context) {
    final String texto;
    if (resultado.sinDatos) {
      texto = 'No se pudo calcular: falta algún producto';
    } else if (resultado.ilimitado) {
      texto = 'ilimitado';
    } else if (resultado.agotado) {
      texto = 'Agotado · sin ${resultado.limita}';
    } else if (resultado.stock == null) {
      texto = '—';
    } else {
      texto = '${resultado.stock} · limita: ${resultado.limita}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bordeMedio),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16),
          const SizedBox(width: 8),
          Text('Stock', style: TextStyle(color: AppColors.muted)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              key: const Key('stock-combo'),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
