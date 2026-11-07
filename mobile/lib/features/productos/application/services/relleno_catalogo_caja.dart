import '../../domain/models/producto.dart';
import 'campos_catalogo_producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// RellenoCatalogoCaja
// ═════════════════════════════════════════════════════════════════════════
// Qué campos del catálogo de Caja le faltan a un producto viejo (guardado
// antes de 3g). Función pura: solo decide, no escribe.
//
//   nombreBusqueda → se calcula del nombre
//   tipoCaja       → se calcula de lo que el producto es
//   vendidos       → 0 (el producto viejo no tiene ventas contadas)
//
// Lo que ya está bien NO se vuelve a escribir (sobre todo `vendidos`: un
// producto con ventas contadas nunca se reinicia).
// ═════════════════════════════════════════════════════════════════════════
abstract final class RellenoCatalogoCaja {
  /// Tope de productos que Caja prepara por negocio. Con más, no se escribe
  /// nada y se avisa.
  static const int maximoProductos = 500;

  /// Los campos que faltan o están mal formados; vacío si el producto está
  /// completo.
  static Map<String, Object> camposFaltantes(
    Map<String, dynamic> datos,
    Producto producto,
  ) {
    final faltan = <String, Object>{};
    if (datos['nombreBusqueda'] is! String) {
      faltan['nombreBusqueda'] = CamposCatalogoProducto.nombreBusqueda(
        producto.nombre,
      );
    }
    final tipo = datos['tipoCaja'];
    if (tipo is! String || !CamposCatalogoProducto.tipos.contains(tipo)) {
      faltan['tipoCaja'] = CamposCatalogoProducto.tipoCaja(producto);
    }
    if (datos['vendidos'] is! int) {
      faltan['vendidos'] = 0;
    }
    return faltan;
  }
}
