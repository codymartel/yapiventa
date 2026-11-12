import 'package:flutter/foundation.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/services/validacion_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/use_cases/anular_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/pedidos/domain/models/pedido_por.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../application/services/carrito_caja.dart';
import '../../application/services/constructor_linea_caja.dart';
import '../../application/services/id_aleatorio_caja.dart';
import '../../application/services/mensajes_cobro_caja.dart';
import '../../domain/models/opciones_caja.dart';
import '../../domain/models/resultado_cobro_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// VentaCajaProvider
// ═════════════════════════════════════════════════════════════════════════
// La venta que arma el cajero: carrito, entrega, forma de pago, datos del
// cliente y el cobro. Todo en enteros; la cuenta sale de
// `CalculoVentaMostrador` (nada se escribe a mano).
//
// Contra el doble cobro: la venta tiene un id desde que se empieza a armar.
// Si el cobro falla (sin conexión, falta stock…) el id y el carrito se
// CONSERVAN: reintentar con el mismo id no cobra dos veces. Solo al
// registrarse se estrena un id nuevo y se vacía el carrito.
//
// No habla con Firestore: usa el caso de uso `RegistrarVentaMostrador`.
// ═════════════════════════════════════════════════════════════════════════
class VentaCajaProvider extends ChangeNotifier {
  VentaCajaProvider({
    required this.negocioId,
    required this._registrar,
    this._anular,
    this.opcionesPago = const [],
    this.zonas = const [],
    String Function()? generarId,
  }) : _generarId = generarId ?? idAleatorioCaja,
       _pago = opcionesPago.isEmpty ? null : opcionesPago.first {
    _idVenta = _generarId();
  }

  final String negocioId;
  final RegistrarVentaMostrador _registrar;
  final AnularVentaMostrador? _anular;
  final String Function() _generarId;
  final List<OpcionPagoCaja> opcionesPago;
  final List<ZonaCaja> zonas;

  late String _idVenta;
  CarritoCaja _carrito = const CarritoCaja();
  EntregaCaja _entrega = EntregaCaja.local;
  OpcionPagoCaja? _pago;
  ZonaCaja? _zona;
  PedidoPor? _pedidoPor;
  String _cliente = '';
  String _telefono = '';
  String _direccion = '';
  String _notas = '';
  bool _cobrarAlEntregar = false;
  bool _cobrando = false;
  bool _bloqueado = false;

  String get idVenta => _idVenta;
  CarritoCaja get carrito => _carrito;
  EntregaCaja get entrega => _entrega;
  OpcionPagoCaja? get pago => _pago;
  ZonaCaja? get zona => _zona;

  /// «¿Lo pidió antes para recoger?»: null = No. Solo en el local.
  PedidoPor? get pedidoPor => _pedidoPor;
  String get cliente => _cliente;
  String get telefono => _telefono;
  String get direccion => _direccion;
  String get notas => _notas;
  bool get cobrarAlEntregar => _cobrarAlEntregar;
  bool get cobrando => _cobrando;

  /// Las ventas están bloqueadas (por ejemplo, mientras se prepara el
  /// catálogo). No se puede cobrar.
  bool get bloqueado => _bloqueado;

  bool get esDelivery => _entrega == EntregaCaja.delivery;

  int get _deliveryCentavos => esDelivery ? (_zona?.costoCentavos ?? 0) : 0;

  /// La cuenta de hoy: subtotal, delivery, descuento y total, en céntimos.
  VentaCalculada get venta => CalculoVentaMostrador.calcular(
    lineas: _carrito.lineas,
    deliveryCentavos: _deliveryCentavos,
    descuento: _pago?.descuento ?? DescuentoPago.ninguno,
  );

  /// Qué falta o sobra para cobrar, con las mismas reglas que aplica el caso
  /// de uso (delivery pide cliente, teléfono, zona y dirección).
  ResultadoValidacionVenta get validacion => ValidacionVentaMostrador.validar(
    lineas: _carrito.lineas,
    metodoPago: _pago?.id ?? '',
    tipoEntrega: _entrega.tipo,
    cliente: _clienteDeLaVenta,
    zona: esDelivery ? (_zona?.nombre ?? '') : '',
    nota: _notas,
  );

  /// «Falta: teléfono y dirección», para escribirlo bajo el botón apagado.
  /// null si se puede cobrar o si el carrito está vacío (no hay qué avisar).
  String? get motivoNoCobrar {
    if (_carrito.vacio) return null;
    if (_bloqueado) return MensajesCobroCaja.ventasBloqueadas;
    final v = validacion;
    return v.ok ? null : v.mensaje;
  }

  bool get puedeCobrar => !_cobrando && !_bloqueado && validacion.ok;

  ClientePedido get _clienteDeLaVenta => ClientePedido(
    nombre: _cliente.trim(),
    telefono: _telefono.trim(),
    direccion: esDelivery ? _direccion.trim() : '',
  );

  // ── Carrito ───────────────────────────────────────────────────────────

  /// Agrega un producto. Devuelve el motivo si no se pudo (null = agregado).
  String? agregarProducto(
    Producto producto, {
    required int cantidad,
    String modeloId = '',
    String filaId = '',
    List<String> extrasIds = const [],
  }) {
    final linea = ConstructorLineaCaja.construir(
      producto,
      cantidad: cantidad,
      modeloId: modeloId,
      filaId: filaId,
      extrasIds: extrasIds,
    );
    if (!linea.ok) return linea.error;
    final r = _carrito.agregar(linea.linea!);
    if (!r.ok) return r.error;
    _carrito = r.carrito;
    notifyListeners();
    return null;
  }

  void cambiarCantidad(String clave, int cantidad) {
    _carrito = _carrito.conCantidad(clave, cantidad);
    notifyListeners();
  }

  void quitar(String clave) {
    _carrito = _carrito.quitar(clave);
    notifyListeners();
  }

  /// Vacía el carrito y los datos, pero conserva el id: es la misma venta.
  void vaciar() {
    _limpiar();
    notifyListeners();
  }

  // ── Entrega, pago y datos ─────────────────────────────────────────────

  void elegirEntrega(EntregaCaja entrega) {
    _entrega = entrega;
    if (!esDelivery) {
      _cobrarAlEntregar = false;
    }
    if (!entrega.enLocal) {
      _pedidoPor = null;
    }
    notifyListeners();
  }

  void elegirPago(OpcionPagoCaja? pago) {
    _pago = pago;
    notifyListeners();
  }

  /// Solo en el local; null = «No».
  void elegirPedidoPor(PedidoPor? valor) {
    _pedidoPor = _entrega.enLocal ? valor : null;
    notifyListeners();
  }

  void elegirZona(ZonaCaja? zona) {
    _zona = zona;
    notifyListeners();
  }

  void escribirCliente(String valor) {
    _cliente = valor;
    notifyListeners();
  }

  void escribirTelefono(String valor) {
    _telefono = valor;
    notifyListeners();
  }

  void escribirDireccion(String valor) {
    _direccion = valor;
    notifyListeners();
  }

  void escribirNotas(String valor) {
    _notas = valor;
    notifyListeners();
  }

  /// Solo delivery: el pago queda pendiente hasta entregar.
  void cobrarAlEntregarActivo(bool valor) {
    _cobrarAlEntregar = esDelivery && valor;
    notifyListeners();
  }

  /// Bloquea o libera el cobro desde afuera.
  void bloquearVentas(bool valor) {
    if (_bloqueado == valor) return;
    _bloqueado = valor;
    notifyListeners();
  }

  // ── Cobrar ────────────────────────────────────────────────────────────

  Future<ResultadoCobroCaja> cobrar() async {
    if (_cobrando) return const ResultadoCobroCaja(TipoCobroCaja.ignorado);
    if (_bloqueado) {
      return const ResultadoCobroCaja(
        TipoCobroCaja.ignorado,
        mensaje: MensajesCobroCaja.ventasBloqueadas,
      );
    }
    _cobrando = true;
    notifyListeners();
    try {
      final r = await _registrar.ejecutar(
        negocioId: negocioId,
        idVenta: _idVenta,
        lineas: _carrito.lineas,
        tipoEntrega: _entrega.tipo,
        enLocal: _entrega.enLocal,
        pedidoPor: _entrega.enLocal ? _pedidoPor : null,
        metodoPago: _pago?.id ?? '',
        cliente: _clienteDeLaVenta,
        zona: esDelivery ? (_zona?.nombre ?? '') : '',
        deliveryCentavos: _deliveryCentavos,
        descuento: _pago?.descuento ?? DescuentoPago.ninguno,
        notas: _notas,
        cobrarAlEntregar: _cobrarAlEntregar,
      );

      final motivo = MensajesCobroCaja.noSeCobro(r);
      if (motivo != null) {
        return ResultadoCobroCaja(
          r.invalida != null
              ? TipoCobroCaja.faltanDatos
              : TipoCobroCaja.bloqueado,
          mensaje: motivo,
        );
      }

      final res = r.resultado!;
      final total = venta.totalCentavos;
      _limpiar();
      _idVenta = _generarId();
      return ResultadoCobroCaja(
        res.yaRegistrada ? TipoCobroCaja.yaRegistrada : TipoCobroCaja.exito,
        mensaje: res.yaRegistrada
            ? MensajesCobroCaja.yaRegistrada
            : MensajesCobroCaja.registrada(total),
        pedidoId: res.pedidoId,
        clave: res.clave,
        totalCentavos: total,
        descuentos: res.descuentos,
      );
    } on ArgumentError {
      return const ResultadoCobroCaja(
        TipoCobroCaja.error,
        mensaje: 'No se pudo cobrar: la cuenta de la venta no cuadra.',
      );
    } catch (_) {
      return const ResultadoCobroCaja(
        TipoCobroCaja.error,
        mensaje: MensajesCobroCaja.sinConexion,
      );
    } finally {
      _cobrando = false;
      notifyListeners();
    }
  }

  /// «Anular» del aviso tras cobrar: devuelve el stock y resta del día. La
  /// venta queda anulada, no se borra. `ok` dice si la lista debe devolver el
  /// stock en memoria (false si ya estaba anulada o falló).
  Future<({bool ok, String mensaje})> anularVenta(String pedidoId) async {
    final anular = _anular;
    if (anular == null) {
      return (ok: false, mensaje: MensajesCobroCaja.noSeAnulo);
    }
    try {
      final r = await anular(negocioId: negocioId, pedidoId: pedidoId);
      if (r.yaAnulada) {
        return (ok: false, mensaje: MensajesCobroCaja.yaAnulada);
      }
      return (ok: true, mensaje: MensajesCobroCaja.anulada(r.sinDevolver));
    } on StateError {
      return (ok: false, mensaje: MensajesCobroCaja.yaNoSeAnula);
    } catch (_) {
      return (ok: false, mensaje: MensajesCobroCaja.noSeAnulo);
    }
  }

  void _limpiar() {
    _carrito = const CarritoCaja();
    _zona = null;
    _pedidoPor = null;
    _cliente = '';
    _telefono = '';
    _direccion = '';
    _notas = '';
    _cobrarAlEntregar = false;
  }
}
