import '../../../negocio/domain/models/catalogo_venta/formateador_presentacion.dart';
import '../../domain/models/calculador_venta_medida.dart';
import '../../domain/models/dinero.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/regla_venta_medida.dart';
import 'cantidades_tipicas.dart';

// ═════════════════════════════════════════════════════════════════════════
// VistaPreviaMedida
// ═════════════════════════════════════════════════════════════════════════
// Cómo verá el cliente un producto por medida: precio de cada cantidad
// rápida y lo que recibe al pedir por monto. Todo en enteros y con el mismo
// CalculadorVentaMedida que usa la venta (redondeo hacia abajo, a favor del
// cliente). Función pura, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════

/// Una cantidad rápida con su precio: "¼ kg · S/ 1.12" (la etiqueta sale de
/// CantidadesTipicas: la unidad más natural, no la habitual del negocio).
class CantidadRapidaConPrecio {
  const CantidadRapidaConPrecio({
    required this.cantidadBase,
    required this.etiqueta,
    required this.precioCentavos,
  });

  final int cantidadBase;
  final String etiqueta;
  final int precioCentavos;
}

/// Resultado de un pedido por monto: cantidad entregada y lo que se cobra,
/// o el motivo por el que no alcanza.
class PedidoPorMonto {
  const PedidoPorMonto({
    required this.montoCentavos,
    this.cantidadBase,
    this.etiqueta = '',
    this.costoCentavos,
    this.error,
  });

  final int montoCentavos;
  final int? cantidadBase;
  final String etiqueta;
  final int? costoCentavos;
  final String? error;

  bool get esValido => error == null && cantidadBase != null;
}

class VistaPreviaMedida {
  VistaPreviaMedida._();

  /// Monto de ejemplo para la vista previa: S/ 2.00.
  static const int montoEjemploCentavos = 200;

  /// Regla del producto; null si algún dato falta o no es positivo.
  static ReglaVentaMedida? regla({
    required FamiliaUnidad familia,
    required int precioCentavos,
    required int referenciaBase,
    required int minimoBase,
    required int incrementoBase,
    bool permiteMonto = false,
  }) {
    if (familia == FamiliaUnidad.conteo) return null;
    if (precioCentavos <= 0 || referenciaBase <= 0) return null;
    if (minimoBase <= 0 || incrementoBase <= 0) return null;
    return ReglaVentaMedida(
      familia: familia,
      cantidadReferenciaBase: FormateadorPresentacion.cantidadEnFamilia(
        familia,
        referenciaBase,
      ),
      precioReferenciaCentimos: Dinero(precioCentavos),
      cantidadMinimaBase: FormateadorPresentacion.cantidadEnFamilia(
        familia,
        minimoBase,
      ),
      incrementoBase: FormateadorPresentacion.cantidadEnFamilia(
        familia,
        incrementoBase,
      ),
      permitePedidoPorMonto: permiteMonto,
    );
  }

  /// Cantidades rápidas que respetan mínimo e incremento, con su precio.
  static List<CantidadRapidaConPrecio> cantidadesRapidas(
    ReglaVentaMedida regla,
    List<int> rapidasBase,
  ) {
    final minimo = regla.cantidadMinimaBase.valor;
    final incremento = regla.incrementoBase.valor;
    final resultado = <CantidadRapidaConPrecio>[];
    for (final base in rapidasBase) {
      if (base < minimo || (base - minimo) % incremento != 0) continue;
      final cantidad = FormateadorPresentacion.cantidadEnFamilia(
        regla.familia,
        base,
      );
      final precio = CalculadorVentaMedida.calcularPrecio(regla, cantidad);
      if (precio.precio == null) continue;
      resultado.add(
        CantidadRapidaConPrecio(
          cantidadBase: base,
          etiqueta: CantidadesTipicas.etiqueta(regla.familia, base),
          precioCentavos: precio.precio!.centimos,
        ),
      );
    }
    return resultado;
  }

  /// Lo que recibe el cliente si pide [montoCentavos]. null si la regla no
  /// permite pedido por monto.
  static PedidoPorMonto? porMonto(
    ReglaVentaMedida regla, {
    int montoCentavos = montoEjemploCentavos,
  }) {
    if (!regla.permitePedidoPorMonto) return null;
    final resultado = CalculadorVentaMedida.calcularCantidadDesdeMonto(
      regla,
      Dinero(montoCentavos),
    );
    final cantidad = resultado.cantidad;
    if (!resultado.esValido || cantidad == null) {
      return PedidoPorMonto(
        montoCentavos: montoCentavos,
        error: resultado.error,
      );
    }
    return PedidoPorMonto(
      montoCentavos: montoCentavos,
      cantidadBase: cantidad.valor,
      etiqueta: CantidadesTipicas.etiqueta(regla.familia, cantidad.valor),
      costoCentavos: resultado.costo!.centimos,
    );
  }
}
