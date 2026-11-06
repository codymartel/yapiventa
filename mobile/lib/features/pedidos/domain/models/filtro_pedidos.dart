// ═════════════════════════════════════════════════════════════════════════
// FiltroPedidos
// ═════════════════════════════════════════════════════════════════════════
// Qué pedidos trae cada pestaña de la pantalla. Cada filtro es UNA consulta a
// Firestore (con su índice) y siempre del más nuevo al más viejo:
//   nuevos     → estado nuevo
//   activos    → confirmado, en camino y listo
//   todos      → todos los abiertos (nuevo, confirmado, en camino y listo)
//   porCobrar  → sin cobrar y no cancelados (incluye los ya entregados)
//   reembolsos → cancelados que ya estaban pagados y falta devolver el dinero
// ═════════════════════════════════════════════════════════════════════════
enum FiltroPedidos { nuevos, activos, todos, porCobrar, reembolsos }
