import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/productos/application/services/cantidades_tipicas.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import 'constructor_linea_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// SeleccionProductoCaja · CalculoHojaProducto
// ═════════════════════════════════════════════════════════════════════════
// Lo que el cajero va eligiendo en la hoja del producto y lo que eso significa:
// la línea de venta, cuánto cuesta, cómo se resume y si se puede agregar.
// Funciones puras, todo en enteros (céntimos y unidad base).
//
//   contable   → cantidad en unidades (stepper)
//   por medida → cantidad en unidad BASE (350 g); el precio cubre la cantidad
//                de referencia y se redondea hacia abajo UNA vez
//   variable   → modelo (color) y fila (talla) obligatorios; el stock es el
//                de la fila
//   combo      → sin modelos ni extras; su stock se comprueba al cobrar
// ═════════════════════════════════════════════════════════════════════════
class SeleccionProductoCaja {
  const SeleccionProductoCaja({
    this.modeloId = '',
    this.filaId = '',
    this.cantidad = 1,
    this.extrasIds = const {},
  });

  final String modeloId;
  final String filaId;

  /// Unidades si se cuenta; unidad base (g, ml, mm, cm²) si es por medida.
  final int cantidad;
  final Set<String> extrasIds;

  SeleccionProductoCaja copyWith({
    String? modeloId,
    String? filaId,
    int? cantidad,
    Set<String>? extrasIds,
  }) {
    return SeleccionProductoCaja(
      modeloId: modeloId ?? this.modeloId,
      filaId: filaId ?? this.filaId,
      cantidad: cantidad ?? this.cantidad,
      extrasIds: extrasIds ?? this.extrasIds,
    );
  }

  /// Cambiar de modelo borra la fila (cada modelo tiene sus filas).
  SeleccionProductoCaja conModelo(String id) => SeleccionProductoCaja(
    modeloId: id,
    cantidad: cantidad,
    extrasIds: extrasIds,
  );

  SeleccionProductoCaja conExtra(String id, bool puesto) {
    final nuevos = {...extrasIds};
    if (puesto) {
      nuevos.add(id);
    } else {
      nuevos.remove(id);
    }
    return copyWith(extrasIds: nuevos);
  }
}

class ResumenHojaProducto {
  const ResumenHojaProducto({
    this.linea,
    this.subtotalCentavos = 0,
    this.resumen = '',
    this.falta,
    this.stockDisponible,
    this.noAlcanza = false,
  });

  /// La línea lista para agregar; null si falta elegir algo.
  final LineaPedido? linea;
  final int subtotalCentavos;

  /// «Azul · M · bordado», «350 g». Vacío si no hay nada que resumir.
  final String resumen;

  /// Lo que falta elegir («Elige el modelo y cómo se vende.»).
  final String? falta;

  /// Cuánto hay (unidades o unidad base). null = ilimitado o no se sabe.
  final int? stockDisponible;

  /// Lo elegido pasa de lo que hay.
  final bool noAlcanza;

  bool get puedeAgregar => linea != null && !noAlcanza;
}

abstract final class CalculoHojaProducto {
  /// Tope de unidades que se puede subir con el stepper cuando no se sabe el
  /// stock (ilimitado o combo).
  static const int maximoContable = 999;

  static ResumenHojaProducto calcular(
    Producto producto,
    SeleccionProductoCaja seleccion,
  ) {
    final stock = stockDe(producto, seleccion);
    final noAlcanza = stock != null && seleccion.cantidad > stock;
    final r = ConstructorLineaCaja.construir(
      producto,
      cantidad: seleccion.cantidad,
      modeloId: seleccion.modeloId,
      filaId: seleccion.filaId,
      extrasIds: seleccion.extrasIds.toList(),
    );
    final linea = r.linea;
    if (linea == null) {
      return ResumenHojaProducto(
        falta: r.error,
        stockDisponible: stock,
        noAlcanza: noAlcanza,
      );
    }
    return ResumenHojaProducto(
      linea: linea,
      subtotalCentavos: CalculoVentaMostrador.calcular(
        lineas: [linea],
      ).subtotalCentavos,
      resumen: _resumen(producto, linea),
      stockDisponible: stock,
      noAlcanza: noAlcanza,
    );
  }

  /// El stock de lo elegido: el de la fila si hay variables, el del producto
  /// si no. null = ilimitado, o un combo (se comprueba al cobrar).
  static int? stockDe(Producto p, SeleccionProductoCaja s) {
    if (p.esStockInfinito || p.esCombo) return null;
    if (p.tieneModelos) {
      final fila = _fila(p, s);
      if (fila == null) return null;
      return p.esPorMedida ? (fila.stockBase ?? 0) : fila.stock;
    }
    return p.esPorMedida ? (p.stockBase ?? 0) : p.stock;
  }

  /// Hasta dónde sube el stepper de un producto que se cuenta.
  static int maximoDe(Producto p, SeleccionProductoCaja s) {
    final stock = stockDe(p, s);
    return stock ?? maximoContable;
  }

  /// Las cantidades rápidas de un producto por medida (¼ kg, ½ kg, 1 kg…),
  /// de la familia de su unidad. Vacío si no es por medida.
  static List<CantidadTipica> cantidadesRapidas(Producto p) {
    final familia = p.medidaFamilia;
    if (!p.esPorMedida || familia == null) return const [];
    return CantidadesTipicas.de(familia);
  }

  static FilaVenta? _fila(Producto p, SeleccionProductoCaja s) {
    for (final m in p.modelos) {
      if (m.id != s.modeloId) continue;
      for (final f in m.filas) {
        if (f.id == s.filaId) return f;
      }
    }
    return null;
  }

  static String _resumen(Producto p, LineaPedido linea) {
    final partes = <String>[];
    if (linea.porMedida) {
      final familia = p.medidaFamilia;
      partes.add(
        familia == null
            ? '${linea.cantidad}'
            : CantidadesTipicas.etiqueta(familia, linea.cantidad),
      );
    }
    if (linea.etiqueta.isNotEmpty) {
      // Con un solo modelo su nombre no aporta («Pollo · Medio»): se muestra
      // solo la fila («Medio»). La línea guardada conserva la etiqueta entera.
      final fila = p.modelos.length == 1
          ? _fila(
              p,
              SeleccionProductoCaja(
                modeloId: linea.modeloId,
                filaId: linea.filaId,
              ),
            )
          : null;
      partes.add(
        fila != null && fila.etiqueta.isNotEmpty
            ? fila.etiqueta
            : linea.etiqueta,
      );
    }
    for (final e in linea.extras) {
      partes.add(e.nombre.toLowerCase());
    }
    return partes.join(' · ');
  }
}
