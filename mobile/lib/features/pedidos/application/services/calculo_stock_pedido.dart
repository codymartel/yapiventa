import 'package:mobile/features/productos/application/services/totales_producto.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../domain/models/descuento_stock.dart';
import '../../domain/models/linea_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// CalculoStockPedido
// ═════════════════════════════════════════════════════════════════════════
// Qué se descuenta del stock al confirmar un pedido, y cómo se aplica o se
// devuelve sobre un [Producto]. Función pura, sin Flutter ni Firestore; todo
// en enteros.
//
// Reglas (CLAUDE.md):
//   - Se suma TODO el carrito por lugar de stock (producto · modelo · fila):
//     dos líneas del mismo producto compiten por el mismo stock.
//   - Un combo no tiene stock propio: descuenta cada parte × cantidad.
//   - Un producto con stock infinito no descuenta nada.
//   - Todo o nada: si algo no alcanza, el resultado no es [ok] y el llamador
//     no escribe nada.
//   - Cancelar devuelve exactamente lo descontado ([DescuentoStock]), sumando
//     a lo que haya ahora (si el vendedor repuso stock, no se pierde).
// ═════════════════════════════════════════════════════════════════════════
class ResultadoDescuento {
  const ResultadoDescuento({
    this.descuentos = const [],
    this.faltas = const [],
    this.sinProducto = const [],
  });

  final List<DescuentoStock> descuentos;
  final List<FaltaStock> faltas;

  /// Nombres de lo que ya no existe (producto borrado u opción quitada).
  final List<String> sinProducto;

  bool get ok => faltas.isEmpty && sinProducto.isEmpty;
}

class ResultadoAplicar {
  const ResultadoAplicar({required this.producto, this.omitidos = 0});

  final Producto producto;

  /// Descuentos cuya fila u opción ya no existe: no se pudieron aplicar.
  final int omitidos;
}

class _Peticion {
  _Peticion(this.producto, this.modeloId, this.filaId, this.nombre);

  final Producto producto;
  final String modeloId;
  final String filaId;
  final String nombre;
  int cantidad = 0;
}

abstract final class CalculoStockPedido {
  /// Ids de los productos de las líneas (para leerlos antes de calcular).
  static List<String> idsDeLineas(List<LineaPedido> lineas) {
    return {for (final linea in lineas) linea.productoId}.toList();
  }

  /// Ids de las partes de un combo (segunda lectura, solo si hay combos).
  static List<String> idsDePartes(Producto combo) {
    return {for (final parte in combo.partes) parte.productoId}.toList();
  }

  static ResultadoDescuento calcular(
    List<LineaPedido> lineas,
    Producto? Function(String productoId) buscar,
  ) {
    final peticiones = <String, _Peticion>{};
    final sinProducto = <String>[];

    void pedir(
      Producto producto,
      String modeloId,
      String filaId,
      int cantidad,
      String nombre,
    ) {
      if (producto.esStockInfinito) return;
      if (producto.tieneModelos && filaDe(producto, modeloId, filaId) == null) {
        sinProducto.add(nombre);
        return;
      }
      final clave = '${producto.id}|$modeloId|$filaId';
      final peticion = peticiones.putIfAbsent(
        clave,
        () => _Peticion(producto, modeloId, filaId, nombre),
      );
      peticion.cantidad += cantidad;
    }

    for (final linea in lineas) {
      if (linea.cantidad < 1) continue;
      final producto = buscar(linea.productoId);
      if (producto == null) {
        sinProducto.add(linea.nombre);
        continue;
      }
      if (!producto.esCombo) {
        pedir(
          producto,
          linea.modeloId,
          linea.filaId,
          linea.cantidad,
          linea.nombre,
        );
        continue;
      }
      for (final parte in producto.partes) {
        final dePartes = buscar(parte.productoId);
        final nombre = parte.nombre.isEmpty ? linea.nombre : parte.nombre;
        if (dePartes == null) {
          sinProducto.add(nombre);
          continue;
        }
        pedir(
          dePartes,
          parte.modeloId,
          parte.filaId,
          parte.cantidad * linea.cantidad,
          nombre,
        );
      }
    }

    final descuentos = <DescuentoStock>[];
    final faltas = <FaltaStock>[];
    for (final p in peticiones.values) {
      final fila = filaDe(p.producto, p.modeloId, p.filaId);
      final hay = _stockActual(p.producto, fila);
      if (p.cantidad > hay) {
        faltas.add(FaltaStock(nombre: p.nombre, pide: p.cantidad, hay: hay));
        continue;
      }
      descuentos.add(
        DescuentoStock(
          productoId: p.producto.id,
          modeloId: p.modeloId,
          filaId: p.filaId,
          cantidad: p.cantidad,
          enBase: p.producto.esPorMedida,
        ),
      );
    }

    return ResultadoDescuento(
      descuentos: descuentos,
      faltas: faltas,
      sinProducto: sinProducto,
    );
  }

  /// Aplica a [producto] los descuentos que le tocan: los resta, o los suma si
  /// [devolver]. Recalcula los totales derivados del producto con modelos.
  static ResultadoAplicar aplicar(
    Producto producto,
    List<DescuentoStock> descuentos, {
    required bool devolver,
  }) {
    if (producto.esStockInfinito) return ResultadoAplicar(producto: producto);

    var modelos = producto.modelos;
    var stock = producto.stock;
    var stockBase = producto.stockBase;
    var omitidos = 0;
    var cambioUnidades = false;
    var cambioBase = false;

    for (final d in descuentos) {
      if (d.productoId != producto.id) continue;
      final delta = devolver ? d.cantidad : -d.cantidad;
      if (producto.tieneModelos) {
        final fila = filaDe(producto, d.modeloId, d.filaId);
        if (fila == null) {
          omitidos++;
          continue;
        }
        modelos = _conFila(modelos, d.modeloId, fila.id, (f) {
          return d.enBase
              ? f.copyWith(stockBase: _piso((f.stockBase ?? 0) + delta))
              : f.copyWith(stock: _piso(f.stock + delta));
        });
      } else if (d.enBase) {
        stockBase = _piso((stockBase ?? 0) + delta);
      } else {
        stock = _piso(stock + delta);
      }
      if (d.enBase) {
        cambioBase = true;
      } else {
        cambioUnidades = true;
      }
    }

    if (producto.tieneModelos) {
      if (cambioUnidades) stock = TotalesProducto.stockTotal(modelos);
      if (cambioBase) stockBase = TotalesProducto.stockBaseTotal(modelos);
    }

    return ResultadoAplicar(
      producto: producto.copyWith(
        modelos: modelos,
        stock: stock,
        stockBase: stockBase,
      ),
      omitidos: omitidos,
    );
  }

  static int _piso(int valor) => valor < 0 ? 0 : valor;

  /// La fila (modelo · fila) de un producto con variables; null si no existe.
  static FilaVenta? filaDe(Producto producto, String modeloId, String filaId) {
    for (final modelo in producto.modelos) {
      if (modelo.id != modeloId) continue;
      for (final fila in modelo.filas) {
        if (fila.id == filaId) return fila;
      }
    }
    return null;
  }

  static int _stockActual(Producto producto, FilaVenta? fila) {
    if (producto.esPorMedida) {
      return fila == null ? producto.stockBase ?? 0 : fila.stockBase ?? 0;
    }
    return fila?.stock ?? producto.stock;
  }

  static List<ModeloProducto> _conFila(
    List<ModeloProducto> modelos,
    String modeloId,
    String filaId,
    FilaVenta Function(FilaVenta) cambiar,
  ) {
    return [
      for (final modelo in modelos)
        if (modelo.id != modeloId)
          modelo
        else
          modelo.copyWith(
            filas: [
              for (final fila in modelo.filas)
                if (fila.id == filaId) cambiar(fila) else fila,
            ],
          ),
    ];
  }
}
