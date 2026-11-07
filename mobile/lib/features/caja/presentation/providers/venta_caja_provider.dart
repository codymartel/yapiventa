import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/pedidos/application/services/calculo_venta_mostrador.dart';
import 'package:mobile/features/pedidos/application/use_cases/registrar_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/models/descuento_pago.dart';
import 'package:mobile/features/pedidos/domain/models/pedido.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../application/services/carrito_caja.dart';
import '../../application/services/constructor_linea_caja.dart';
import '../../application/services/mensajes_cobro_caja.dart';
import '../../domain/models/opciones_caja.dart';

/// Cómo terminó un intento de cobrar.
enum TipoCobroCaja {
  /// Se registró la venta.
  exito,

  /// Un toque repetido: ya estaba registrada, no se cobró de nuevo.
  yaRegistrada,

  /// Faltan datos o sobran caracteres: no se intentó cobrar.
  faltanDatos,

  /// El stock, un producto o los precios lo impiden: no se escribió nada.
  bloqueado,

  /// Sin conexión u otro fallo: se puede reintentar sin cobrar dos veces.
  error,

  /// Ya había un cobro en curso (doble toque) o las ventas están bloqueadas.
  ignorado,
}

class ResultadoCobroCaja {
  const ResultadoCobroCaja(
    this.tipo, {
    this.mensaje = '',
    this.pedidoId = '',
    this.clave = '',
    this.totalCentavos = 0,
  });

  final TipoCobroCaja tipo;
  final String mensaje;

  /// De la venta registrada (para «Anular» en el aviso).
  final String pedidoId;
  final String clave;
  final int totalCentavos;

  bool get registrada =>
      tipo == TipoCobroCaja.exito || tipo == TipoCobroCaja.yaRegistrada;
}

/// 20 caracteres al azar: el id de la venta desde que se empieza a armar.
String generarIdVenta() {
  const letras =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final azar = Random.secure();
  return List.generate(20, (_) => letras[azar.nextInt(letras.length)]).join();
}

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
    this.opcionesPago = const [],
    this.zonas = const [],
    String Function()? generarId,
  }) : _generarId = generarId ?? generarIdVenta,
       _pago = opcionesPago.isEmpty ? null : opcionesPago.first {
    _idVenta = _generarId();
  }

  final String negocioId;
  final RegistrarVentaMostrador _registrar;
  final String Function() _generarId;
  final List<OpcionPagoCaja> opcionesPago;
  final List<ZonaCaja> zonas;

  late String _idVenta;
  CarritoCaja _carrito = const CarritoCaja();
  EntregaCaja _entrega = EntregaCaja.local;
  OpcionPagoCaja? _pago;
  ZonaCaja? _zona;
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

  bool get puedeCobrar =>
      !_cobrando && !_bloqueado && !_carrito.vacio && _pago != null;

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
    notifyListeners();
  }

  void elegirPago(OpcionPagoCaja? pago) {
    _pago = pago;
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
        metodoPago: _pago?.id ?? '',
        cliente: ClientePedido(
          nombre: _cliente.trim(),
          telefono: _telefono.trim(),
          direccion: esDelivery ? _direccion.trim() : '',
        ),
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

  void _limpiar() {
    _carrito = const CarritoCaja();
    _zona = null;
    _cliente = '';
    _telefono = '';
    _direccion = '';
    _notas = '';
    _cobrarAlEntregar = false;
  }
}
