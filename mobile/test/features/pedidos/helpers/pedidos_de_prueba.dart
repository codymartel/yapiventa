import 'package:mobile/features/pedidos/domain/models/estado_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/linea_pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/productos/domain/models/estructura_producto.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/modo_venta.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

/// Producto que se cuenta, sin modelos (gaseosa, arroz...).
Producto productoSimple({
  String id = 'gaseosa',
  String nombre = 'Gaseosa Inca',
  int stock = 10,
  int precioCentavos = 350,
  bool infinito = false,
}) {
  return Producto(
    id: id,
    negocioId: 'n1',
    nombre: nombre,
    stock: stock,
    precioCentavos: precioCentavos,
    esStockInfinito: infinito,
  );
}

/// Queso por kilo: S/ 24,00 el kg, stock en gramos.
Producto quesoPorMedida({int stockBase = 1200}) {
  return Producto(
    id: 'queso',
    negocioId: 'n1',
    nombre: 'Queso andino',
    modoVenta: ModoVenta.medida,
    medidaFamilia: FamiliaUnidad.peso,
    medidaUnidad: 'kg',
    precioCentavos: 2400,
    cantidadReferenciaBase: 1000,
    stockBase: stockBase,
  );
}

/// Polo con un modelo (Luna) y dos tallas: M con 3 y L con 2 (total 5).
Producto poloConModelos({int stockM = 3, int stockL = 2}) {
  return Producto(
    id: 'polo',
    negocioId: 'n1',
    nombre: 'Polo básico',
    stock: stockM + stockL,
    precioCentavos: 5000,
    tituloModelos: 'Color',
    tituloFilas: 'Talla',
    modelos: [
      ModeloProducto(
        id: 'luna',
        nombre: 'Luna',
        filas: [
          FilaVenta(
            id: 'm',
            etiqueta: 'M',
            precioCentavos: 5000,
            stock: stockM,
          ),
          FilaVenta(
            id: 'l',
            etiqueta: 'L',
            precioCentavos: 5500,
            stock: stockL,
          ),
        ],
      ),
    ],
  );
}

/// Combo: 1 gaseosa + 2 papas, a S/ 15,00.
Producto comboGaseosaYPapas() {
  return Producto(
    id: 'combo',
    negocioId: 'n1',
    nombre: 'Combo personal',
    precioCentavos: 1500,
    partes: const [
      ParteCombo(productoId: 'gaseosa', cantidad: 1, nombre: 'Gaseosa Inca'),
      ParteCombo(productoId: 'papas', cantidad: 2, nombre: 'Papas'),
    ],
  );
}

LineaPedido lineaSimple({
  String productoId = 'gaseosa',
  String nombre = 'Gaseosa Inca',
  int cantidad = 1,
  int precioCentavos = 350,
  String modeloId = '',
  String filaId = '',
  List<ExtraLinea> extras = const [],
}) {
  return LineaPedido(
    productoId: productoId,
    modeloId: modeloId,
    filaId: filaId,
    nombre: nombre,
    cantidad: cantidad,
    precioCentavos: precioCentavos,
    extras: extras,
  );
}

/// Queso por medida: [gramos] a S/ 24,00 el kg.
LineaPedido lineaQueso(int gramos) {
  return LineaPedido(
    productoId: 'queso',
    nombre: 'Queso andino',
    cantidad: gramos,
    precioCentavos: 2400,
    porMedida: true,
    cantidadReferencia: 1000,
  );
}

Pedido pedidoDe(
  List<LineaPedido> lineas, {
  String id = 'ped1',
  EstadoPedido estado = EstadoPedido.nuevo,
  EstadoPago pago = EstadoPago.pendiente,
  TipoEntrega entrega = TipoEntrega.delivery,
  DateTime? fecha,
  int deliveryCentavos = 0,
  int descuentoCentavos = 0,
  int? totalCentavos,
}) {
  var subtotal = 0;
  for (final linea in lineas) {
    subtotal += linea.subtotalCentavos;
  }
  return Pedido(
    id: id,
    estado: estado,
    estadoPago: pago,
    tipoEntrega: entrega,
    fecha: fecha,
    lineas: lineas,
    deliveryCentavos: deliveryCentavos,
    descuentoCentavos: descuentoCentavos,
    subtotalCentavos: subtotal,
    totalCentavos: totalCentavos ?? subtotal + deliveryCentavos,
  );
}
