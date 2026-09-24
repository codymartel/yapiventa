import 'cantidad_base.dart';
import 'dinero.dart';
import 'familia_unidad.dart';
import 'regla_venta_medida.dart';

// ═════════════════════════════════════════════════════════════════════════
// CalculadorVentaMedida
// ═════════════════════════════════════════════════════════════════════════
// Cálculo puro (sin UI, sin I/O) para productos vendidos por medida.
//
// REGLA DE REDONDEO (única y explícita):
//   - calcularPrecio: producto de cantidades enteras; si el precio no es
//     exacto se redondea HACIA ABAJO con `~/` (nunca se cobra más de lo
//     que corresponde, y nunca se produce un céntimo aparte).
//   - calcularCantidadDesdeMonto: primero convierte el monto a la máxima
//     cantidad entera que no lo supere, y luego la baja al último escalón
//     válido (>= mínimo y alineado al incremento). Garantía: el costo de la
//     cantidad devuelta JAMÁS supera el monto solicitado.
//
// Toda la aritmética es entera: sin double, sin redondeo de punto flotante.
// ═════════════════════════════════════════════════════════════════════════

sealed class ResultadoCalculo {
  const ResultadoCalculo();
}

/// Resultado de calcular un precio desde una cantidad.
class ResultadoPrecio extends ResultadoCalculo {
  final Dinero? precio;
  final String? error;

  ResultadoPrecio._({this.precio, this.error})
    : assert(
        (precio == null) != (error == null),
        'Debe venir precio o error, no ambos.',
      ),
      assert(
        precio == null || precio.centimos > 0,
        'Un precio calculado siempre es positivo.',
      );

  ResultadoPrecio.ok(Dinero precio) : this._(precio: precio);

  ResultadoPrecio.error(String error) : this._(error: error);

  bool get esValido => error == null;
}

/// Resultado de convertir un monto en cantidad (pedido por monto).
class ResultadoCantidad extends ResultadoCalculo {
  final CantidadBase? cantidad;
  final Dinero? costo;
  final String? error;

  ResultadoCantidad._({this.cantidad, this.costo, this.error})
    : assert(
        (cantidad == null) != (error == null),
        'Debe venir cantidad (y costo) o error, no ambos.',
      );

  ResultadoCantidad.ok(CantidadBase cantidad, Dinero costo)
    : this._(cantidad: cantidad, costo: costo);

  ResultadoCantidad.error(String error) : this._(error: error);

  bool get esValido => error == null;
}

class CalculadorVentaMedida {
  CalculadorVentaMedida._();

  /// Valida que la cantidad no sea cero ni negativa (en su familia).
  static String? validarPositivo(CantidadBase cantidad) {
    if (cantidad.valor <= 0) {
      return 'La cantidad debe ser mayor que 0.';
    }
    return null;
  }

  /// Valida que la cantidad respete el mínimo de la regla.
  static String? validarMinimo(ReglaVentaMedida regla, CantidadBase cantidad) {
    if (cantidad.valor < regla.cantidadMinimaBase.valor) {
      return 'La cantidad mínima es ${regla.cantidadMinimaBase.valor}.';
    }
    return null;
  }

  /// Valida que la cantidad sea >= mínimo y esté alineada al incremento
  /// (cantidad - mínimo) % incremento == 0. Solo entero, sin flotantes.
  static String? validarIncremento(
    ReglaVentaMedida regla,
    CantidadBase cantidad,
  ) {
    final sobreMinimo = cantidad.valor - regla.cantidadMinimaBase.valor;
    if (sobreMinimo < 0) return validarMinimo(regla, cantidad);
    if (sobreMinimo % regla.incrementoBase.valor != 0) {
      return 'La cantidad debe avanzar de ${regla.incrementoBase.valor} en '
          '${regla.incrementoBase.valor} desde ${regla.cantidadMinimaBase.valor}.';
    }
    return null;
  }

  /// Valida que la cantidad no supere el stock disponible (unidades base).
  /// Un stock negativo se interpreta como "solo lectura / sin stock real".
  static String? validarStock(int stockDisponible, CantidadBase cantidad) {
    if (stockDisponible >= 0 && cantidad.valor > stockDisponible) {
      return 'Stock insuficiente: hay $stockDisponible disponibles.';
    }
    return null;
  }

  /// Calcula el precio (en céntimos) de la cantidad. Redondea hacia abajo.
  static ResultadoPrecio calcularPrecio(
    ReglaVentaMedida regla,
    CantidadBase cantidad,
  ) {
    final error = validarPositivo(cantidad);
    if (error != null) return ResultadoPrecio.error(error);

    final centimos =
        (cantidad.valor * regla.precioReferenciaCentimos.centimos) ~/
        regla.cantidadReferenciaBase.valor;
    return ResultadoPrecio.ok(Dinero(centimos));
  }

  /// Convierte un monto en la cantidad máxima cuyo costo no supera el
  /// monto y que además respeta mínimo e incremento. Requiere que la
  /// regla permita pedido por monto.
  static ResultadoCantidad calcularCantidadDesdeMonto(
    ReglaVentaMedida regla,
    Dinero monto, {
    int stockDisponible = -1,
  }) {
    if (!regla.permitePedidoPorMonto) {
      return ResultadoCantidad.error(
        'Este producto no permite pedidos por monto.',
      );
    }
    if (monto.centimos <= 0) {
      return ResultadoCantidad.error('El monto debe ser mayor que 0.');
    }

    // Cantidad máxima (entera, hacia abajo) que el monto puede comprar.
    var cantidad =
        (monto.centimos * regla.cantidadReferenciaBase.valor) ~/
        regla.precioReferenciaCentimos.centimos;

    if (cantidad < regla.cantidadMinimaBase.valor) {
      return ResultadoCantidad.error(
        'El monto no alcanza el mínimo de '
        '${regla.cantidadMinimaBase.valor}.',
      );
    }

    // Bajamos al último escalón <= cantidad alineado al incremento,
    // sin bajar del mínimo.
    final sobreMinimo = cantidad - regla.cantidadMinimaBase.valor;
    final escalones = sobreMinimo ~/ regla.incrementoBase.valor;
    cantidad =
        regla.cantidadMinimaBase.valor + escalones * regla.incrementoBase.valor;

    // Garantía explícita de redondeo: el costo de lo entregado nunca
    // supera el monto solicitado.
    final costoParcial = calcularPrecio(regla, _cantidad(regla, cantidad));
    if (costoParcial.precio == null ||
        costoParcial.precio!.centimos > monto.centimos) {
      return ResultadoCantidad.error(
        'El monto no permite una cantidad válida.',
      );
    }

    final errorStock = validarStock(
      stockDisponible,
      _cantidad(regla, cantidad),
    );
    if (errorStock != null) return ResultadoCantidad.error(errorStock);

    return ResultadoCantidad.ok(
      _cantidad(regla, cantidad),
      costoParcial.precio!,
    );
  }

  static CantidadBase _cantidad(ReglaVentaMedida regla, int valor) {
    return switch (regla.familia) {
      FamiliaUnidad.conteo => CantidadBase.unidades(valor),
      FamiliaUnidad.peso => CantidadBase.gramos(valor),
      FamiliaUnidad.volumen => CantidadBase.mililitros(valor),
      FamiliaUnidad.longitud => CantidadBase.milimetros(valor),
      FamiliaUnidad.area => CantidadBase.centimetrosCuadrados(valor),
    };
  }
}
