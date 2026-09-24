// ═════════════════════════════════════════════════════════════════════════
// ModoVenta
// ═════════════════════════════════════════════════════════════════════════
// Cómo se vende un producto. Fase 1 del dominio de cantidades: reemplaza
// la dualidad fracionaria/entera del antiguo TipoUnidad por un modo de
// venta explícito.
//
// REGLAS DE NEGOCIO:
//   - presentacion: se vende contando presentaciones (unidad, par, caja,
//     botella, docena...). El stock SIEMPRE es entero. El contenido de una
//     presentación (ej. "botella de 625 ml") es información del producto,
//     NO stock medido.
//   - medida: se vende por alguna familia de unidad medible (peso,
//     volumen, longitud, área) con su regla de venta asociada.
//
// "Pedido por monto" NO es un tercer modo de venta: pertenece a medida y
// se habilita en ReglaVentaMedida.permitePedidoPorMonto.
// ═════════════════════════════════════════════════════════════════════════
enum ModoVenta {
  /// Se vende contando presentaciones enteras (unidades, pares, botellas).
  presentacion,

  /// Se vende por una familia de medida (peso, volumen, longitud, área).
  medida,
}
