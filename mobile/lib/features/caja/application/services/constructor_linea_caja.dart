import 'package:mobile/features/pedidos/application/services/calculo_stock_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConstructorLineaCaja
// ═════════════════════════════════════════════════════════════════════════
// Arma la línea de una venta a partir del producto y de lo que eligió el
// cajero. Función pura, en enteros. Usa el MISMO precio que usa el panel al
// verificar un pedido (`CalculoPedido`):
//
//   precio       → el del producto; con modelos (y no combo), el de la fila
//   por medida   → la cantidad va en UNIDAD BASE (350 g) y el precio cubre la
//                  cantidad de referencia (S/ 24,00 por 1 000 g)
//   extras       → solo en lo que se cuenta; no se descuentan ni tienen stock
//   combo        → sin modelos ni extras; sus partes se descuentan solas
//
// Si algo falta, devuelve un mensaje en español simple y NO una línea.
// ═════════════════════════════════════════════════════════════════════════
class ResultadoLineaCaja {
  const ResultadoLineaCaja._(this.linea, this.error);

  const ResultadoLineaCaja.ok(LineaPedido linea) : this._(linea, null);

  const ResultadoLineaCaja.error(String mensaje) : this._(null, mensaje);

  final LineaPedido? linea;
  final String? error;

  bool get ok => linea != null;
}

abstract final class ConstructorLineaCaja {
  static ResultadoLineaCaja construir(
    Producto producto, {
    required int cantidad,
    String modeloId = '',
    String filaId = '',
    List<String> extrasIds = const [],
  }) {
    if (!producto.disponible) {
      return const ResultadoLineaCaja.error(
        'Este producto no está disponible.',
      );
    }
    if (cantidad <= 0) {
      return const ResultadoLineaCaja.error(
        'La cantidad debe ser mayor que cero.',
      );
    }

    var precio = producto.precioCentavos;
    var etiqueta = '';
    if (producto.tieneModelos && !producto.esCombo) {
      final modelo = producto.modelos
          .where((m) => m.id == modeloId)
          .firstOrNull;
      final fila = CalculoStockPedido.filaDe(producto, modeloId, filaId);
      if (modelo == null || fila == null) {
        return const ResultadoLineaCaja.error(
          'Elige el modelo y cómo se vende.',
        );
      }
      precio = fila.precioCentavos;
      etiqueta = [
        modelo.nombre,
        fila.etiqueta,
      ].where((t) => t.trim().isNotEmpty).join(' · ');
    }

    final porMedida = producto.esPorMedida && !producto.esCombo;
    if (porMedida && producto.cantidadReferenciaBase <= 0) {
      return const ResultadoLineaCaja.error(
        'Este producto no tiene su medida de referencia.',
      );
    }

    final extras = <ExtraLinea>[];
    if (extrasIds.isNotEmpty) {
      if (porMedida || producto.esCombo) {
        return const ResultadoLineaCaja.error('Este producto no lleva extras.');
      }
      for (final id in extrasIds.toSet()) {
        final extra = producto.extras.where((e) => e.id == id).firstOrNull;
        if (extra == null) {
          return const ResultadoLineaCaja.error('Un extra ya no existe.');
        }
        extras.add(
          ExtraLinea(
            nombre: extra.nombre,
            precioCentavos: extra.precioCentavos,
          ),
        );
      }
    }

    return ResultadoLineaCaja.ok(
      LineaPedido(
        productoId: producto.id,
        modeloId: modeloId,
        filaId: filaId,
        nombre: producto.nombre,
        etiqueta: etiqueta,
        cantidad: cantidad,
        precioCentavos: precio,
        porMedida: porMedida,
        cantidadReferencia: porMedida ? producto.cantidadReferenciaBase : 1,
        extras: extras,
        esCombo: producto.esCombo,
      ),
    );
  }
}
