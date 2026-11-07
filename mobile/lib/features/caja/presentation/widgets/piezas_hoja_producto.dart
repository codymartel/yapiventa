import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/mensajes_cobro_caja.dart';

// Las piezas de la hoja del producto (maqueta, pantalla «Producto»): títulos,
// chips de elección, filas con su stock, extras y el stepper de cantidad.
// Solo dibujan: el estado vive en `HojaProductoCaja`.

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Un chip de elección (modelo, extra, cantidad rápida).
class OpcionChip extends StatelessWidget {
  const OpcionChip({
    super.key,
    required this.etiqueta,
    required this.activa,
    required this.onTap,
    this.habilitada = true,
  });

  final String etiqueta;
  final bool activa;
  final bool habilitada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      enabled: habilitada,
      child: Opacity(
        opacity: habilitada ? 1 : 0.45,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: habilitada ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: activa ? AppColors.blueLt.withValues(alpha: 0.22) : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: activa ? AppColors.blueLt : AppColors.bordeMedio,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activa) ...[
                  const Icon(Icons.check, size: 16, color: AppColors.azulTexto),
                  const SizedBox(width: 6),
                ],
                Text(
                  etiqueta,
                  style: TextStyle(
                    color: activa ? AppColors.azulTexto : AppColors.muted,
                    fontSize: 13,
                    fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila «Se vende en» (talla, número, formato) con su stock y su precio.
/// Agotada se ve apagada y no se puede elegir (siempre con el texto).
class FilaOpcion extends StatelessWidget {
  const FilaOpcion({
    super.key,
    required this.fila,
    required this.stockTexto,
    required this.activa,
    required this.agotada,
    required this.onTap,
  });

  final FilaVenta fila;
  final String stockTexto;
  final bool activa;
  final bool agotada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      enabled: !agotada,
      child: Opacity(
        opacity: agotada ? 0.45 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: agotada ? null : onTap,
          child: Container(
            width: 84,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: activa ? AppColors.blueLt.withValues(alpha: 0.22) : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: activa ? AppColors.blueLt : AppColors.bordeMedio,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fila.etiqueta.isEmpty ? 'Única' : fila.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: activa ? AppColors.azulTexto : AppColors.texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (agotada || stockTexto.isNotEmpty)
                  Text(
                    agotada ? 'Agotado' : stockTexto,
                    style: const TextStyle(color: AppColors.hint, fontSize: 11),
                  ),
                Text(
                  MensajesCobroCaja.dinero(fila.precioCentavos),
                  style: const TextStyle(
                    color: AppColors.azulTexto,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El texto de un extra: «Ají extra + S/ 1,00» (o «gratis»).
String etiquetaExtra(ExtraProducto e) {
  return e.precioCentavos > 0
      ? '${e.nombre} + ${MensajesCobroCaja.dinero(e.precioCentavos)}'
      : '${e.nombre} (gratis)';
}

/// El stepper de cantidad: dos botones de 44 px y el número en medio.
class StepperCantidad extends StatelessWidget {
  const StepperCantidad({
    super.key,
    required this.cantidad,
    required this.minimo,
    required this.maximo,
    required this.onCambio,
  });

  final int cantidad;
  final int minimo;
  final int maximo;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Quitar una unidad',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.remove, color: AppColors.azulTexto),
            onPressed: cantidad > minimo ? () => onCambio(cantidad - 1) : null,
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Agregar una unidad',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.add, color: AppColors.azulTexto),
            onPressed: cantidad < maximo ? () => onCambio(cantidad + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Lo que se muestra del stock de una fila («3 disp.»).
String stockDeFila(FilaVenta f, {required bool porMedida}) {
  if (porMedida) return '';
  return '${f.stock} disp.';
}

/// Para reutilizar el texto del producto en el encabezado.
String lineaPrecioStock(String precio, String stock) =>
    stock.isEmpty ? precio : '$precio · hay $stock';
