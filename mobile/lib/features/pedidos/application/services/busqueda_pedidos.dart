import '../../domain/models/pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// BusquedaPedidos
// ═════════════════════════════════════════════════════════════════════════
// Busca por clave, nombre del cliente o teléfono ENTRE LOS YA CARGADOS (0
// lecturas). No distingue mayúsculas ni tildes. El teléfono se compara solo
// por dígitos («987 654» encuentra «987654321»). Pura.
// ═════════════════════════════════════════════════════════════════════════
abstract final class BusquedaPedidos {
  static List<Pedido> filtrar(List<Pedido> pedidos, String texto) {
    final buscado = _normalizar(texto);
    if (buscado.isEmpty) return pedidos;
    final digitos = _soloDigitos(texto);
    return [
      for (final p in pedidos)
        if (_coincide(p, buscado, digitos)) p,
    ];
  }

  static bool _coincide(Pedido p, String buscado, String digitos) {
    if (_normalizar(p.clave).contains(buscado)) return true;
    if (_normalizar(p.cliente.nombre).contains(buscado)) return true;
    return digitos.length >= 3 &&
        _soloDigitos(p.cliente.telefono).contains(digitos);
  }

  static String _soloDigitos(String texto) =>
      texto.replaceAll(RegExp(r'[^0-9]'), '');

  static String _normalizar(String texto) {
    const conTilde = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sinTilde = 'aaaaeeeeiiiioooouuuun';
    final minuscula = texto.trim().toLowerCase();
    final salida = StringBuffer();
    for (final c in minuscula.split('')) {
      final i = conTilde.indexOf(c);
      salida.write(i >= 0 ? sinTilde[i] : c);
    }
    return salida.toString();
  }
}
