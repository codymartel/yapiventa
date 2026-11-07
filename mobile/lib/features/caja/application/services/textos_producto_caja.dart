import 'package:mobile/features/productos/application/services/campos_catalogo_producto.dart';
import 'package:mobile/features/productos/application/services/textos_tarjeta_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextosProductoCaja
// ═════════════════════════════════════════════════════════════════════════
// Precio, stock y tipo de la tarjeta de Caja, con coma decimal («S/ 4,50»,
// «16,65 kg»). Reutilizan los textos de la tarjeta de Productos, que escriben
// el punto decimal (unificar es un pendiente aparte). Funciones puras.
// ═════════════════════════════════════════════════════════════════════════
abstract final class TextosProductoCaja {
  static final RegExp _decimal = RegExp(r'(\d)\.(\d{1,2})(?!\d)');

  static String _coma(String texto) =>
      texto.replaceAllMapped(_decimal, (m) => '${m[1]},${m[2]}');

  /// «S/ 4,50», «S/ 24,00 / kg», «desde S/ 35,00».
  static String precio(Producto p) => _coma(TextosTarjetaProducto.precio(p));

  /// «22 uds.», «16,65 kg», «ilimitado».
  static String stock(Producto p) => _coma(TextosTarjetaProducto.stock(p));

  /// La palabra corta del tipo de producto («Por peso», «Combo»…); vacío si
  /// es un producto simple.
  static String tipo(Producto p) {
    return switch (CamposCatalogoProducto.tipoCaja(p)) {
      CamposCatalogoProducto.tipoMedida => 'Por peso',
      CamposCatalogoProducto.tipoVariable => 'Variable',
      CamposCatalogoProducto.tipoCombo => 'Combo',
      _ => '',
    };
  }
}
