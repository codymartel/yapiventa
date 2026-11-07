import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/application/services/entrada_numerica.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/calculo_hoja_producto.dart';
import '../../application/services/textos_producto_caja.dart';
import 'chip_caja.dart';
import 'piezas_hoja_producto.dart';

// Las secciones donde el cajero elige (maqueta, pantalla «Producto»). Cada
// una dibuja lo suyo y avisa el cambio con `onCambiar`: el estado y el cálculo
// no viven aquí (están en `HojaProductoCaja` y `CalculoHojaProducto`).

/// Modelo (color) y fila (talla) con su stock. Con un solo modelo, o una sola
/// fila, no hay nada que elegir y esa parte no se dibuja.
class SeccionVariablesHoja extends StatelessWidget {
  const SeccionVariablesHoja({
    super.key,
    required this.producto,
    required this.seleccion,
    required this.onCambiar,
  });

  final Producto producto;
  final SeleccionProductoCaja seleccion;
  final ValueChanged<SeleccionProductoCaja> onCambiar;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final porMedida = p.esPorMedida;
    final modelo = p.modelos
        .where((m) => m.id == seleccion.modeloId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.modelos.length > 1) ...[
          TituloSeccion(p.tituloModelos.isEmpty ? 'Modelo' : p.tituloModelos),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in p.modelos)
                ChipCaja(
                  marcarActivo: true,
                  altoMinimo: 44,
                  etiqueta: m.nombre,
                  activo: m.id == seleccion.modeloId,
                  onTap: () => onCambiar(
                    CalculoHojaProducto.elegirModelo(p, seleccion, m.id),
                  ),
                ),
            ],
          ),
        ],
        if (modelo != null && modelo.filas.length > 1) ...[
          TituloSeccion(p.tituloFilas.isEmpty ? 'Se vende en' : p.tituloFilas),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in modelo.filas)
                FilaOpcion(
                  fila: f,
                  stockTexto: p.esStockInfinito
                      ? ''
                      : TextosProductoCaja.stockDeFila(f, porMedida: porMedida),
                  activa: f.id == seleccion.filaId,
                  // Con stock ilimitado las filas guardan 0: no están agotadas.
                  agotada:
                      !p.esStockInfinito &&
                      (porMedida ? (f.stockBase ?? 0) <= 0 : f.stock <= 0),
                  onTap: () => onCambiar(seleccion.copyWith(filaId: f.id)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Los extras opcionales («Ají extra + S/ 1,00»): un toque los pone y otro
/// los quita.
class SeccionExtrasHoja extends StatelessWidget {
  const SeccionExtrasHoja({
    super.key,
    required this.producto,
    required this.seleccion,
    required this.onCambiar,
  });

  final Producto producto;
  final SeleccionProductoCaja seleccion;
  final ValueChanged<SeleccionProductoCaja> onCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Extras (opcional)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in producto.extras)
              ChipCaja(
                marcarActivo: true,
                altoMinimo: 44,
                etiqueta: TextosProductoCaja.etiquetaExtra(e),
                activo: seleccion.extrasIds.contains(e.id),
                onTap: () => onCambiar(
                  seleccion.conExtra(e.id, !seleccion.extrasIds.contains(e.id)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Producto que se cuenta (o combo): stepper de cantidad hasta lo que hay.
class SeccionCantidadContable extends StatelessWidget {
  const SeccionCantidadContable({
    super.key,
    required this.producto,
    required this.seleccion,
    required this.resumen,
    required this.onCambiar,
  });

  final Producto producto;
  final SeleccionProductoCaja seleccion;
  final ResumenHojaProducto resumen;
  final ValueChanged<SeleccionProductoCaja> onCambiar;

  @override
  Widget build(BuildContext context) {
    final maximo = CalculoHojaProducto.maximoDe(producto, seleccion);
    final stock = resumen.stockDisponible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Cantidad'),
        Row(
          children: [
            StepperCantidad(
              cantidad: seleccion.cantidad,
              minimo: 1,
              maximo: maximo < 1 ? 1 : maximo,
              onCambio: (n) => onCambiar(seleccion.copyWith(cantidad: n)),
            ),
            const SizedBox(width: 12),
            if (stock != null && stock > 0)
              Expanded(
                child: Text(
                  seleccion.cantidad >= stock
                      ? 'Es todo lo que hay'
                      : 'Hay $stock',
                  style: TextStyle(
                    color: seleccion.cantidad >= stock
                        ? AppColors.aviso
                        : AppColors.muted,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Producto por medida: cantidades rápidas (¼ kg, ½ kg, 1 kg…) y «Otra
/// cantidad» escrita en la unidad base (350 g). Las que pasan del stock quedan
/// apagadas. Guarda lo que se está escribiendo; la cantidad elegida la avisa
/// con `onCambiar`.
class SeccionCantidadPeso extends StatefulWidget {
  const SeccionCantidadPeso({
    super.key,
    required this.producto,
    required this.seleccion,
    required this.resumen,
    required this.onCambiar,
  });

  final Producto producto;
  final SeleccionProductoCaja seleccion;
  final ResumenHojaProducto resumen;
  final ValueChanged<SeleccionProductoCaja> onCambiar;

  @override
  State<SeccionCantidadPeso> createState() => _SeccionCantidadPesoState();
}

class _SeccionCantidadPesoState extends State<SeccionCantidadPeso> {
  final TextEditingController _otra = TextEditingController();
  bool _otraCantidad = false;
  String? _errorOtra;

  @override
  void dispose() {
    _otra.dispose();
    super.dispose();
  }

  UnidadRegistrada _unidadBase(FamiliaUnidad familia) {
    return RegistroUnidades.unidadesDe(
      familia,
    ).firstWhere((u) => u.factorBase == 1);
  }

  void _escribirOtra(String texto) {
    final familia = widget.producto.medidaFamilia;
    if (familia == null) return;
    final base = _unidadBase(familia);
    final r = textoAUnidadBase(texto, 1, unidadBase: base.nombre);
    final sel = widget.seleccion;
    setState(() {
      _errorOtra = texto.trim().isEmpty || r.esValida ? null : r.error;
    });
    widget.onCambiar(
      sel.copyWith(
        cantidad: texto.trim().isNotEmpty && r.esValida ? r.base! : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final sel = widget.seleccion;
    final rapidas = CalculoHojaProducto.cantidadesRapidas(p);
    final stock = widget.resumen.stockDisponible;
    final base = _unidadBase(p.medidaFamilia!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('¿Cuánto se lleva?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in rapidas)
              ChipCaja(
                marcarActivo: true,
                altoMinimo: 44,
                etiqueta: c.etiqueta,
                activo: !_otraCantidad && sel.cantidad == c.base,
                habilitado: stock == null || c.base <= stock,
                onTap: () {
                  setState(() {
                    _otraCantidad = false;
                    _errorOtra = null;
                  });
                  widget.onCambiar(sel.copyWith(cantidad: c.base));
                },
              ),
            ChipCaja(
              marcarActivo: true,
              altoMinimo: 44,
              etiqueta: 'Otra cantidad',
              activo: _otraCantidad,
              onTap: () {
                setState(() {
                  _otraCantidad = true;
                  _errorOtra = null;
                  _otra.clear();
                });
                widget.onCambiar(sel.copyWith(cantidad: 0));
              },
            ),
          ],
        ),
        if (_otraCantidad) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otra,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.texto, fontSize: 16),
            cursorColor: AppColors.azulTexto,
            decoration: InputDecoration(
              hintText: 'Cantidad en ${base.nombre}',
              suffixText: base.nombre,
              errorText: _errorOtra,
              border: const OutlineInputBorder(),
            ),
            onChanged: _escribirOtra,
          ),
        ],
      ],
    );
  }
}
