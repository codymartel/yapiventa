import '../../domain/models/linea_pedido.dart';
import '../../domain/models/pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// ValidacionVentaMostrador
// ═════════════════════════════════════════════════════════════════════════
// Qué datos pide Caja según la entrega, con los mismos límites de tamaño que
// exigen las reglas de Firestore (nombre 80, teléfono 20, dirección 200, zona
// 60, nota 500):
//
//   En el local y recojo → solo productos y forma de pago (el cliente es un
//                          alias opcional, por ejemplo «Mesa 4»)
//   Delivery             → además cliente, teléfono, zona y dirección
//
// Función pura: devuelve qué falta y qué se pasa de largo, y el mensaje en
// español simple para mostrarlo.
// ═════════════════════════════════════════════════════════════════════════
enum CampoVenta {
  productos('productos'),
  formaPago('forma de pago'),
  cliente('cliente'),
  telefono('teléfono'),
  zona('zona'),
  direccion('dirección'),
  nota('nota');

  const CampoVenta(this.etiqueta);

  final String etiqueta;
}

class ResultadoValidacionVenta {
  const ResultadoValidacionVenta({
    this.faltan = const [],
    this.muyLargos = const [],
  });

  final List<CampoVenta> faltan;
  final List<CampoVenta> muyLargos;

  bool get ok => faltan.isEmpty && muyLargos.isEmpty;

  /// «Falta: teléfono, zona y dirección» (o «Es muy largo: nota»).
  String get mensaje {
    final partes = <String>[];
    if (faltan.isNotEmpty) partes.add('Falta: ${_unir(faltan)}');
    if (muyLargos.isNotEmpty) partes.add('Es muy largo: ${_unir(muyLargos)}');
    return partes.join('. ');
  }

  static String _unir(List<CampoVenta> campos) {
    final nombres = [for (final c in campos) c.etiqueta];
    if (nombres.length == 1) return nombres.single;
    return '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
  }
}

abstract final class ValidacionVentaMostrador {
  static const int maxNombre = 80;
  static const int maxTelefono = 20;
  static const int maxDireccion = 200;
  static const int maxZona = 60;
  static const int maxNota = 500;

  /// Cifras mínimas para tomar un teléfono como válido.
  static const int minDigitosTelefono = 7;

  static ResultadoValidacionVenta validar({
    required List<LineaPedido> lineas,
    required String metodoPago,
    required TipoEntrega tipoEntrega,
    ClientePedido cliente = const ClientePedido(),
    String zona = '',
    String nota = '',
  }) {
    final faltan = <CampoVenta>[];
    final largos = <CampoVenta>[];

    if (!lineas.any((l) => l.cantidad > 0)) faltan.add(CampoVenta.productos);
    if (metodoPago.trim().isEmpty) faltan.add(CampoVenta.formaPago);

    if (tipoEntrega == TipoEntrega.delivery) {
      if (cliente.nombre.trim().isEmpty) faltan.add(CampoVenta.cliente);
      if (_digitos(cliente.telefono) < minDigitosTelefono) {
        faltan.add(CampoVenta.telefono);
      }
      if (zona.trim().isEmpty) faltan.add(CampoVenta.zona);
      if (cliente.direccion.trim().isEmpty) faltan.add(CampoVenta.direccion);
    }

    if (cliente.nombre.trim().length > maxNombre) {
      largos.add(CampoVenta.cliente);
    }
    if (cliente.telefono.trim().length > maxTelefono) {
      largos.add(CampoVenta.telefono);
    }
    if (cliente.direccion.trim().length > maxDireccion) {
      largos.add(CampoVenta.direccion);
    }
    if (zona.trim().length > maxZona) largos.add(CampoVenta.zona);
    if (nota.trim().length > maxNota) largos.add(CampoVenta.nota);

    return ResultadoValidacionVenta(faltan: faltan, muyLargos: largos);
  }

  static int _digitos(String texto) {
    return texto.replaceAll(RegExp(r'[^0-9]'), '').length;
  }
}
