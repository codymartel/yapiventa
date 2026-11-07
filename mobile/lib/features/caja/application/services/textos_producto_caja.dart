import 'package:mobile/features/productos/application/services/campos_catalogo_producto.dart';
import 'package:mobile/features/productos/application/services/textos_tarjeta_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import 'mensajes_cobro_caja.dart';

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

  /// El texto de un extra: «Ají extra + S/ 1,00» (o «Ají extra (gratis)»).
  static String etiquetaExtra(ExtraProducto e) {
    return e.precioCentavos > 0
        ? '${e.nombre} + ${MensajesCobroCaja.dinero(e.precioCentavos)}'
        : '${e.nombre} (gratis)';
  }

  /// Lo que se muestra del stock de una fila («3 disp.»); vacío por medida.
  static String stockDeFila(FilaVenta f, {required bool porMedida}) {
    if (porMedida) return '';
    return '${f.stock} disp.';
  }

  /// «S/ 4,50 · hay 22 uds.» (o solo el precio si no hay stock que decir).
  static String precioYStock(String precio, String stock) =>
      stock.isEmpty ? precio : '$precio · hay $stock';
}
