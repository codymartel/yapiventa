import '../../domain/models/pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// ListaPedidosPaginada
// ═════════════════════════════════════════════════════════════════════════
// La lista de una pestaña (Nuevos, Activos): los [tamano] pedidos más nuevos
// que llegan EN VIVO ([cabeza]) más las páginas más viejas que el vendedor
// pidió con «Ver más» ([mas], lecturas puntuales que no se actualizan solas).
//
// Un pedido nunca aparece dos veces: si ya está en la cabeza en vivo, manda
// esa copia (la más fresca). Del más nuevo al más viejo; uno sin fecha (el
// servidor aún la está escribiendo) es el más nuevo de todos.
//
// Inmutable y sin Flutter ni Firestore: cada cambio devuelve una lista nueva.
// ═════════════════════════════════════════════════════════════════════════
class ListaPedidosPaginada {
  ListaPedidosPaginada({
    this.tamano = 10,
    this.cabeza = const [],
    this.mas = const [],
    this._hayMasTrasPagina,
  });

  /// Cuántos pedidos trae cada página (y la cabeza en vivo).
  final int tamano;

  /// Los más nuevos, en vivo.
  final List<Pedido> cabeza;

  /// Páginas más viejas pedidas con «Ver más», en el orden en que llegaron.
  final List<Pedido> mas;

  /// null = todavía no se pidió ninguna página.
  final bool? _hayMasTrasPagina;

  /// Todos los pedidos de la pestaña, sin repetidos.
  late final List<Pedido> pedidos = _unir();

  /// ¿Puede haber más pedidos viejos? Antes de la primera página: si la
  /// cabeza salió completa. Después: lo que dijo la última página.
  bool get hayMas => _hayMasTrasPagina ?? cabeza.length >= tamano;

  /// Número para la insignia de la pestaña: «3», o «10+» si hay más sin cargar.
  /// Sale de lo ya cargado: no cuesta ninguna lectura.
  String get etiquetaConteo =>
      hayMas ? '${pedidos.length}+' : '${pedidos.length}';

  /// El pedido desde el cual pedir la página siguiente: el más viejo con fecha.
  Pedido? get ultimoConFecha {
    for (var i = pedidos.length - 1; i >= 0; i--) {
      if (pedidos[i].fecha != null) return pedidos[i];
    }
    return null;
  }

  /// Llegó una nueva foto de los más recientes (el listener en vivo).
  ListaPedidosPaginada conCabeza(List<Pedido> vivos) {
    return ListaPedidosPaginada(
      tamano: tamano,
      cabeza: List.unmodifiable(vivos),
      mas: mas,
      hayMasTrasPagina: _hayMasTrasPagina,
    );
  }

  /// Llegó una página de «Ver más». [hayMas] es lo que dijo el repositorio.
  ListaPedidosPaginada conPagina(List<Pedido> pagina, {required bool hayMas}) {
    return ListaPedidosPaginada(
      tamano: tamano,
      cabeza: cabeza,
      mas: List.unmodifiable([...mas, ...pagina]),
      hayMasTrasPagina: hayMas,
    );
  }

  /// Quita un pedido ya cargado con «Ver más» (cambió de estado y esa copia
  /// quedó vieja). Los de la cabeza se corrigen solos con el listener.
  ListaPedidosPaginada sinPedidoViejo(String id) {
    if (!mas.any((p) => p.id == id)) return this;
    return ListaPedidosPaginada(
      tamano: tamano,
      cabeza: cabeza,
      mas: List.unmodifiable(mas.where((p) => p.id != id)),
      hayMasTrasPagina: _hayMasTrasPagina,
    );
  }

  /// Descarta lo traído con «Ver más» (jalar para actualizar).
  ListaPedidosPaginada sinPaginas() {
    if (mas.isEmpty && _hayMasTrasPagina == null) return this;
    return ListaPedidosPaginada(tamano: tamano, cabeza: cabeza);
  }

  List<Pedido> _unir() {
    final vistos = <String>{};
    final union = <Pedido>[];
    for (final pedido in [...cabeza, ...mas]) {
      if (vistos.add(pedido.id)) union.add(pedido);
    }
    // Estable: los de igual fecha conservan el orden en que llegaron.
    final indexados = [for (var i = 0; i < union.length; i++) (i, union[i])];
    indexados.sort((a, b) {
      final fa = a.$2.fecha;
      final fb = b.$2.fecha;
      if (fa == null && fb == null) return a.$1.compareTo(b.$1);
      if (fa == null) return -1;
      if (fb == null) return 1;
      final c = fb.compareTo(fa);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return List.unmodifiable([for (final e in indexados) e.$2]);
  }
}
