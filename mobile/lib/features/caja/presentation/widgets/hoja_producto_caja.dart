import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/calculo_hoja_producto.dart';
import '../../application/services/mensajes_cobro_caja.dart';
import 'bloques_hoja_producto.dart';
import 'botones_caja.dart';
import 'hoja_caja.dart';
import 'mostrar_hoja_producto.dart';
import 'secciones_seleccion_producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// HojaProductoCaja
// ═════════════════════════════════════════════════════════════════════════
// La hoja para elegir un producto (maqueta «2 · Producto»). Guarda lo que el
// cajero va eligiendo y arma la hoja con sus partes:
//   - se cuenta: cantidad con stepper (sube hasta lo que hay);
//   - por medida: cantidades rápidas (¼ kg, ½ kg, 1 kg…) y «Otra cantidad»
//     en la unidad base (350 g);
//   - variable: modelo (color) y fila (talla) con su stock, y extras;
//   - combo: su precio propio y la cantidad.
// Todo se calcula con `CalculoHojaProducto` (enteros). Dos botones: «Agregar
// y cobrar» y «Agregar y seguir», apagados mientras falte algo, con el motivo
// dicho en texto, fijos abajo. Cómo se abre está en `mostrarHojaProducto`.
// ═════════════════════════════════════════════════════════════════════════
class HojaProductoCaja extends StatefulWidget {
  const HojaProductoCaja({
    super.key,
    required this.producto,
    required this.onConfirmar,
    required this.onCerrar,
  });

  final Producto producto;
  final String? Function(SeleccionProductoCaja, AccionHojaProducto) onConfirmar;
  final ValueChanged<AccionHojaProducto> onCerrar;

  @override
  State<HojaProductoCaja> createState() => _HojaProductoCajaState();
}

class _HojaProductoCajaState extends State<HojaProductoCaja> {
  late SeleccionProductoCaja _sel;
  String? _errorAgregar;

  Producto get _p => widget.producto;
  bool get _porMedida => _p.esPorMedida && !_p.esCombo;

  @override
  void initState() {
    super.initState();
    _sel = CalculoHojaProducto.seleccionInicial(_p);
  }

  void _cambiar(SeleccionProductoCaja nueva) {
    setState(() {
      _sel = nueva;
      _errorAgregar = null;
    });
  }

  void _agregar(AccionHojaProducto accion) {
    final error = widget.onConfirmar(_sel, accion);
    if (error != null) {
      setState(() => _errorAgregar = error);
      return;
    }
    widget.onCerrar(accion);
  }

  @override
  Widget build(BuildContext context) {
    final resumen = CalculoHojaProducto.calcular(_p, _sel);
    final sinStock = resumen.stockDisponible == 0;
    final cuerpo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoHoja(
          producto: _p,
          onCambiar: () => widget.onCerrar(AccionHojaProducto.cambiar),
        ),
        if (_p.tieneModelos && !_p.esCombo)
          SeccionVariablesHoja(
            producto: _p,
            seleccion: _sel,
            onCambiar: _cambiar,
          ),
        if (_p.extras.isNotEmpty && !_porMedida && !_p.esCombo)
          SeccionExtrasHoja(producto: _p, seleccion: _sel, onCambiar: _cambiar),
        if (_porMedida)
          SeccionCantidadPeso(
            producto: _p,
            seleccion: _sel,
            resumen: resumen,
            onCambiar: _cambiar,
          )
        else
          SeccionCantidadContable(
            producto: _p,
            seleccion: _sel,
            resumen: resumen,
            onCambiar: _cambiar,
          ),
        const SizedBox(height: 16),
        TotalHoja(
          resumen: resumen,
          porMedida: _porMedida,
          sinStock: sinStock,
          cantidadElegida: _sel.cantidad,
          falta: CalculoHojaProducto.faltaElegir(_p, _sel, resumen),
        ),
      ],
    );
    // Fijo abajo: con el teclado abierto («Otra cantidad») sigue a la vista.
    final pie = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorAgregar != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _errorAgregar!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        BotonPrincipalCaja(
          texto: resumen.puedeAgregar
              ? 'Agregar y cobrar · ${MensajesCobroCaja.dinero(resumen.subtotalCentavos)}'
              : 'Agregar y cobrar',
          onTap: resumen.puedeAgregar
              ? () => _agregar(AccionHojaProducto.agregarYCobrar)
              : null,
        ),
        const SizedBox(height: 8),
        BotonSecundarioCaja(
          texto: 'Agregar y seguir',
          onTap: resumen.puedeAgregar
              ? () => _agregar(AccionHojaProducto.agregarYSeguir)
              : null,
        ),
      ],
    );
    return CuerpoConPieFijo(cuerpo: cuerpo, pie: pie);
  }
}
