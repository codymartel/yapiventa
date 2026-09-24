import 'cantidad_base.dart';
import 'dinero.dart';
import 'familia_unidad.dart';

// ═════════════════════════════════════════════════════════════════════════
// ReglaVentaMedida
// ═════════════════════════════════════════════════════════════════════════
// Reglas que gobiernan a un producto vendido POR MEDIDA dentro de una
// familia concreta:
//
//   - familia:            la familia física (peso, volumen, longitud, area).
//   - cantidadReferencia: la cantidad base contra la que se cotiza el
//                         precio, ej. 1000 g (1 kg). Vive en la unidad base
//                         de la familia (gramos aquí).
//   - precioReferencia:   el precio de esa cantidad de referencia, siempre
//                         en céntimos.
//   - cantidadMinima:     mínimo vendible en la unidad base.
//   - incremento:         escalón permitido sobre el mínimo, en unidad base.
//   - permitePedidoPorMonto: si es true, el cliente puede pedir "S/ 5 de
//                         arroz" y el sistema convierte el monto a cantidad.
//
// "Pedido por monto" NO es un tercer modo de venta: solo se habilita aquí
// cuando el producto es ModoVenta.medida.
// ═════════════════════════════════════════════════════════════════════════
class ReglaVentaMedida {
  final FamiliaUnidad familia;
  final CantidadBase cantidadReferenciaBase;
  final Dinero precioReferenciaCentimos;
  final CantidadBase cantidadMinimaBase;
  final CantidadBase incrementoBase;
  final bool permitePedidoPorMonto;

  ReglaVentaMedida({
    required this.familia,
    required this.cantidadReferenciaBase,
    required this.precioReferenciaCentimos,
    required this.cantidadMinimaBase,
    required this.incrementoBase,
    this.permitePedidoPorMonto = false,
  }) : assert(
         cantidadReferenciaBase.familia == familia,
         'La referencia debe ser de la misma familia.',
       ),
       assert(
         precioReferenciaCentimos.centimos > 0,
         'El precio de referencia debe ser mayor que 0.',
       ),
       assert(
         cantidadMinimaBase.familia == familia,
         'El mínimo debe ser de la misma familia.',
       ),
       assert(
         incrementoBase.familia == familia,
         'El incremento debe ser de la misma familia.',
       );
}
