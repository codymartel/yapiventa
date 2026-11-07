import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// CarritoCaja
// ═════════════════════════════════════════════════════════════════════════
// Las líneas de la venta que arma el cajero. Inmutable y puro: cada cambio
// devuelve un carrito nuevo. La misma línea (mismo producto, modelo, fila y
// extras) no se repite: se suma su cantidad. Tiene el mismo tope de líneas
// que exigen las reglas de Firestore.
// ═════════════════════════════════════════════════════════════════════════
class ResultadoAgregar {
  const ResultadoAgregar(this.carrito, {this.error});

  final CarritoCaja carrito;

  /// Por qué no se agregó (el carrito queda igual). null = se agregó.
  final String? error;

  bool get ok => error == null;
}

class CarritoCaja {
  const CarritoCaja([this.lineas = const []]);

  /// Igual al tope de las reglas de Firestore para un pedido.
  static const int maximoLineas = 30;

  final List<LineaPedido> lineas;

  bool get vacio => lineas.isEmpty;

  /// Identifica la línea: producto · modelo · fila · extras (en orden fijo).
  static String claveDe(LineaPedido l) {
    final extras = [for (final e in l.extras) '${e.nombre}:${e.precioCentavos}']
      ..sort();
    return '${l.productoId}|${l.modeloId}|${l.filaId}|${extras.join(',')}';
  }

  int cantidadDe(String clave) {
    for (final l in lineas) {
      if (claveDe(l) == clave) return l.cantidad;
    }
    return 0;
  }

  ResultadoAgregar agregar(LineaPedido nueva) {
    if (nueva.cantidad <= 0) {
      return ResultadoAgregar(
        this,
        error: 'La cantidad debe ser mayor que cero.',
      );
    }
    final clave = claveDe(nueva);
    final existe = lineas.any((l) => claveDe(l) == clave);
    if (!existe && lineas.length >= maximoLineas) {
      return ResultadoAgregar(
        this,
        error: 'Una venta admite hasta $maximoLineas productos distintos.',
      );
    }
    final nuevas = existe
        ? [
            for (final l in lineas)
              if (claveDe(l) == clave)
                _conCantidad(l, l.cantidad + nueva.cantidad)
              else
                l,
          ]
        : [...lineas, nueva];
    return ResultadoAgregar(CarritoCaja(nuevas));
  }

  /// Cambia la cantidad de una línea; con 0 o menos la quita.
  CarritoCaja conCantidad(String clave, int cantidad) {
    if (cantidad <= 0) return quitar(clave);
    return CarritoCaja([
      for (final l in lineas)
        if (claveDe(l) == clave) _conCantidad(l, cantidad) else l,
    ]);
  }

  CarritoCaja quitar(String clave) {
    return CarritoCaja([
      for (final l in lineas)
        if (claveDe(l) != clave) l,
    ]);
  }

  static LineaPedido _conCantidad(LineaPedido l, int cantidad) {
    return LineaPedido(
      productoId: l.productoId,
      modeloId: l.modeloId,
      filaId: l.filaId,
      nombre: l.nombre,
      etiqueta: l.etiqueta,
      cantidad: cantidad,
      precioCentavos: l.precioCentavos,
      porMedida: l.porMedida,
      cantidadReferencia: l.cantidadReferencia,
      extras: l.extras,
      esCombo: l.esCombo,
    );
  }
}
