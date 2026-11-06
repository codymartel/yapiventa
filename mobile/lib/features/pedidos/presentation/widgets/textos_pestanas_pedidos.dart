import '../providers/pedidos_provider.dart';

/// «Nuevos 3», «Por cobrar 10+»… El número solo aparece cuando ya se puede
/// mostrar (Nuevos y Activos siempre; las demás, una vez abiertas).
String etiquetaDePestana(PedidosProvider p, PestanaPedidos pestana) {
  if (!p.conteoDisponible(pestana)) return pestana.etiqueta;
  return '${pestana.etiqueta} ${p.conteo(pestana)}';
}

/// Lo que se dice cuando la pestaña no tiene pedidos.
String textoVacioDePestana(PestanaPedidos pestana) {
  return switch (pestana) {
    PestanaPedidos.nuevos => 'No hay pedidos nuevos.',
    PestanaPedidos.activos => 'No hay pedidos activos.',
    PestanaPedidos.porCobrar => 'No hay pedidos por cobrar.',
    PestanaPedidos.reembolsos => 'No hay reembolsos pendientes.',
    PestanaPedidos.todos => 'No hay pedidos abiertos.',
  };
}
