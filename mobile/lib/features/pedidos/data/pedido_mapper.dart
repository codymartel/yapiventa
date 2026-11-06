import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/productos/data/mappers/lectura_firestore.dart';

import '../domain/models/descuento_stock.dart';
import '../domain/models/estado_pedido.dart';
import '../domain/models/linea_pedido.dart';
import '../domain/models/pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// PedidoMapper
// ═════════════════════════════════════════════════════════════════════════
// Documento de Firestore ↔ [Pedido]. La lectura es DEFENSIVA: un campo
// ausente o de otro tipo nunca rompe la lista (un pedido ilegible sería un
// cliente sin atender). Los pedidos los crea la tienda pública; el panel solo
// escribe estado, pago, reembolso, stock descontado e historial.
//
// El historial lleva la hora del dispositivo (Timestamp.fromDate): Firestore
// no permite serverTimestamp dentro de una lista.
// ═════════════════════════════════════════════════════════════════════════
abstract final class PedidoMapper {
  static Pedido desdeFirestore(String id, Map<String, dynamic> data) {
    final clave = LecturaFirestore.texto(data['clave']);
    return Pedido(
      id: id,
      clave: clave.isEmpty ? _claveDeId(id) : clave,
      estado: EstadoPedido.desdeValor(LecturaFirestore.texto(data['estado'])),
      origen: OrigenPedido.desdeValor(LecturaFirestore.texto(data['origen'])),
      tipoEntrega: TipoEntrega.desdeValor(
        LecturaFirestore.texto(data['tipoEntrega']),
      ),
      enLocal: data['enLocal'] == true,
      fecha: _fecha(data['fecha']),
      cliente: _cliente(data['cliente']),
      zona: LecturaFirestore.texto(data['zona']),
      deliveryCentavos: LecturaFirestore.entero(data['deliveryCentavos']),
      descuentoCentavos: LecturaFirestore.entero(data['descuentoCentavos']),
      subtotalCentavos: LecturaFirestore.entero(data['subtotalCentavos']),
      totalCentavos: LecturaFirestore.entero(data['totalCentavos']),
      lineas: [for (final m in _mapas(data['lineas'])) _linea(m)],
      metodoPago: LecturaFirestore.texto(data['metodoPago']),
      estadoPago: EstadoPago.desdeValor(
        LecturaFirestore.texto(data['estadoPago']),
      ),
      notas: LecturaFirestore.texto(data['notas']),
      stockDescontado: [
        for (final m in _mapas(data['stockDescontado'])) _descuento(m),
      ],
      reembolso: EstadoReembolso.desdeValor(
        LecturaFirestore.texto(data['reembolso']),
      ),
      historial: [
        for (final m in _mapas(data['historial']))
          if (_fecha(m['fecha']) case final fecha?)
            CambioEstado(
              estado: EstadoPedido.desdeValor(
                LecturaFirestore.texto(m['estado']),
              ),
              fecha: fecha,
            ),
      ],
    );
  }

  static List<Map<String, dynamic>> descuentosAMapas(
    List<DescuentoStock> descuentos,
  ) {
    return [
      for (final d in descuentos)
        {
          'productoId': d.productoId,
          'modeloId': d.modeloId,
          'filaId': d.filaId,
          'cantidad': d.cantidad,
          'enBase': d.enBase,
        },
    ];
  }

  static List<Map<String, dynamic>> historialAMapas(
    List<CambioEstado> historial,
  ) {
    return [
      for (final c in historial)
        {'estado': c.estado.valor, 'fecha': Timestamp.fromDate(c.fecha)},
    ];
  }

  // ── Lectura de partes ─────────────────────────────────────────────────

  static String _claveDeId(String id) {
    final cola = id.length > 6 ? id.substring(id.length - 6) : id;
    return cola.toUpperCase();
  }

  static DateTime? _fecha(Object? valor) {
    return valor is Timestamp ? valor.toDate() : null;
  }

  static ClientePedido _cliente(Object? valor) {
    if (valor is String) return ClientePedido(nombre: valor.trim());
    if (valor is! Map) return const ClientePedido();
    return ClientePedido(
      nombre: LecturaFirestore.texto(valor['nombre']),
      telefono: LecturaFirestore.texto(valor['telefono']),
      direccion: LecturaFirestore.texto(valor['direccion']),
      correo: LecturaFirestore.texto(valor['correo']),
    );
  }

  static LineaPedido _linea(Map<String, dynamic> m) {
    final referencia = LecturaFirestore.entero(m['cantidadReferencia']);
    return LineaPedido(
      productoId: LecturaFirestore.texto(m['productoId']),
      modeloId: LecturaFirestore.texto(m['modeloId']),
      filaId: LecturaFirestore.texto(m['filaId']),
      nombre: LecturaFirestore.texto(m['nombre']),
      etiqueta: LecturaFirestore.texto(m['etiqueta']),
      cantidad: LecturaFirestore.entero(m['cantidad']),
      precioCentavos: LecturaFirestore.entero(m['precioCentavos']),
      porMedida: m['porMedida'] == true,
      cantidadReferencia: referencia < 1 ? 1 : referencia,
      extras: [
        for (final e in _mapas(m['extras']))
          ExtraLinea(
            nombre: LecturaFirestore.texto(e['nombre']),
            precioCentavos: LecturaFirestore.entero(e['precioCentavos']),
          ),
      ],
      subtotalCentavos: LecturaFirestore.entero(m['subtotalCentavos']),
      esCombo: m['esCombo'] == true,
    );
  }

  static DescuentoStock _descuento(Map<String, dynamic> m) {
    return DescuentoStock(
      productoId: LecturaFirestore.texto(m['productoId']),
      modeloId: LecturaFirestore.texto(m['modeloId']),
      filaId: LecturaFirestore.texto(m['filaId']),
      cantidad: LecturaFirestore.entero(m['cantidad']),
      enBase: m['enBase'] == true,
    );
  }

  static List<Map<String, dynamic>> _mapas(Object? valor) {
    if (valor is! List) return const [];
    return [
      for (final elemento in valor)
        if (elemento is Map) Map<String, dynamic>.from(elemento),
    ];
  }
}
