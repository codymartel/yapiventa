import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../application/services/calculo_hoja_producto.dart';
import 'hoja_caja.dart';
import 'hoja_producto_caja.dart';

/// Qué eligió el cajero al cerrar la hoja.
enum AccionHojaProducto { agregarYCobrar, agregarYSeguir, cambiar }

/// Abre la hoja del producto: hoja desde abajo en celular y tableta (menos
/// de 1 100 px) y diálogo en PC. [onConfirmar] agrega la línea a la venta y devuelve el
/// motivo si no se pudo (por ejemplo, el tope de 30 productos): la hoja lo
/// muestra y NO se cierra. Devuelve la acción elegida, o null si se cerró sin
/// elegir.
Future<AccionHojaProducto?> mostrarHojaProducto(
  BuildContext context, {
  required Producto producto,
  required String? Function(
    SeleccionProductoCaja seleccion,
    AccionHojaProducto accion,
  )
  onConfirmar,
}) {
  Widget contenido(BuildContext c) => HojaProductoCaja(
    producto: producto,
    onConfirmar: onConfirmar,
    onCerrar: (accion) => Navigator.of(c).pop(accion),
  );
  return mostrarHojaCaja<AccionHojaProducto>(
    context,
    anchoMaximo: 480,
    builder: contenido,
  );
}
