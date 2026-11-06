import '../../domain/models/descuento_pago.dart';
import '../../domain/models/linea_pedido.dart';
import '../../domain/models/pedido.dart';
import '../../domain/repositories/repositorio_ventas_mostrador.dart';
import '../services/calculo_venta_mostrador.dart';
import '../services/validacion_venta_mostrador.dart';

/// Lo que devuelve [RegistrarVentaMostrador]: o faltan datos (no se llamó al
/// repositorio) o el resultado de registrar.
class ResultadoRegistroVenta {
  const ResultadoRegistroVenta({this.invalida, this.resultado});

  /// Faltan o sobran datos según la entrega: no se intentó cobrar.
  final ResultadoValidacionVenta? invalida;

  /// Lo que dijo el repositorio (registrada, ya registrada, falta stock, el
  /// precio cambió...). null si la venta era inválida.
  final ResultadoVentaMostrador? resultado;

  bool get registrada => resultado?.registrada ?? false;
}

/// Cobrar una venta de Caja: valida los datos según la entrega, calcula la
/// cuenta en céntimos y la registra en una transacción. Delgado a propósito:
/// la cuenta está en [CalculoVentaMostrador], las reglas de datos en
/// [ValidacionVentaMostrador] y el stock en el repositorio.
class RegistrarVentaMostrador {
  const RegistrarVentaMostrador(this._repositorio);

  final RepositorioVentasMostrador _repositorio;

  Future<ResultadoRegistroVenta> ejecutar({
    required String negocioId,
    required String idVenta,
    required List<LineaPedido> lineas,
    required TipoEntrega tipoEntrega,
    required String metodoPago,
    bool enLocal = false,
    ClientePedido cliente = const ClientePedido(),
    String zona = '',
    int deliveryCentavos = 0,
    DescuentoPago descuento = DescuentoPago.ninguno,
    String notas = '',
    bool cobrarAlEntregar = false,
  }) async {
    final validacion = ValidacionVentaMostrador.validar(
      lineas: lineas,
      metodoPago: metodoPago,
      tipoEntrega: tipoEntrega,
      cliente: cliente,
      zona: zona,
      nota: notas,
    );
    if (!validacion.ok) return ResultadoRegistroVenta(invalida: validacion);

    final venta = CalculoVentaMostrador.calcular(
      lineas: lineas,
      deliveryCentavos: tipoEntrega == TipoEntrega.delivery
          ? deliveryCentavos
          : 0,
      descuento: descuento,
    );
    final resultado = await _repositorio.registrar(
      negocioId,
      SolicitudVentaMostrador(
        idVenta: idVenta,
        lineas: venta.lineas,
        tipoEntrega: tipoEntrega,
        enLocal: enLocal,
        cliente: cliente,
        zona: zona,
        deliveryCentavos: venta.deliveryCentavos,
        descuentoCentavos: venta.descuentoCentavos,
        subtotalCentavos: venta.subtotalCentavos,
        totalCentavos: venta.totalCentavos,
        metodoPago: metodoPago,
        notas: notas,
        cobrarAlEntregar: cobrarAlEntregar,
      ),
    );
    return ResultadoRegistroVenta(resultado: resultado);
  }
}
