import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/calculo_hoja_producto.dart';
import 'hoja_producto_caja.dart';

/// Qué eligió el cajero al cerrar la hoja.
enum AccionHojaProducto { agregarYCobrar, agregarYSeguir, cambiar }

/// Abre la hoja del producto: hoja desde abajo en celular (menos de 900 px) y
/// diálogo en PC. [onConfirmar] agrega la línea a la venta y devuelve el
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
  if (MediaQuery.sizeOf(context).width >= 900) {
    return showDialog<AccionHojaProducto>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.superficie,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: contenido(c),
        ),
      ),
    );
  }
  return showModalBottomSheet<AccionHojaProducto>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: contenido,
  );
}
