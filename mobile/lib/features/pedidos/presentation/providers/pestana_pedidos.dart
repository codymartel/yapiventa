import '../../domain/models/filtro_pedidos.dart';

/// Las pestañas de pedidos. Cada una escucha SU consulta de 10.
enum PestanaPedidos {
  nuevos('Nuevos', FiltroPedidos.nuevos),
  activos('Activos', FiltroPedidos.activos),
  porCobrar('Por cobrar', FiltroPedidos.porCobrar),
  reembolsos('Reembolsos', FiltroPedidos.reembolsos),
  todos('Todos', FiltroPedidos.todos);

  const PestanaPedidos(this.etiqueta, this.filtro);

  final String etiqueta;
  final FiltroPedidos filtro;

  /// Nuevos y Activos se escuchan SIEMPRE (de ahí salen los números, «por
  /// preparar» y los avisos). Las demás, solo mientras se están viendo:
  /// ahorra lecturas.
  bool get siempreEnVivo =>
      this == PestanaPedidos.nuevos || this == PestanaPedidos.activos;
}
