import 'package:mobile/features/productos/domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// DisponibilidadCaja
// ═════════════════════════════════════════════════════════════════════════
// Si un producto de la lista tiene stock y si está bajo, para el filtro
// «solo con stock» y el aviso de la tarjeta. Función pura sobre el producto
// ya cargado (no lee nada). El cobro siempre vuelve a comprobar el stock real
// en la transacción: esto es solo una ayuda visual.
//
// Un combo no tiene stock propio (se calcula de sus partes, que la lista no
// trae): aquí se muestra siempre y el cobro decide.
// ═════════════════════════════════════════════════════════════════════════
abstract final class DisponibilidadCaja {
  /// «Stock bajo»: 3 o menos (fijo, decidido el 2026-11-06).
  static const int limiteStockBajo = 3;

  static bool tieneStock(Producto p) {
    if (p.esStockInfinito || p.esCombo) return true;
    if (p.esPorMedida) return (p.stockBase ?? 0) > 0;
    return p.stock > 0;
  }

  /// Quedan pocas unidades (solo lo que se cuenta; por peso o volumen no hay
  /// un «pocas» que valga para todos).
  static bool stockBajo(Producto p) {
    if (p.esStockInfinito || p.esCombo || p.esPorMedida) return false;
    return p.stock > 0 && p.stock <= limiteStockBajo;
  }
}
