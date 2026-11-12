import '../../domain/models/contadores_dia.dart';
import '../../domain/models/pedido.dart';
import 'resumen_dia_pedidos.dart';
import 'verificacion_total_pedido.dart';

// ═════════════════════════════════════════════════════════════════════════
// ContadoresVenta
// ═════════════════════════════════════════════════════════════════════════
// Lo que una venta suma o resta a los contadores del resumen del día.
// Funciones puras: las usa el repositorio dentro de su transacción.
//
//   aporteDe → lo que aporta un pedido (por entrega, hora, producto,
//              variable y combo; lo cobrado por forma de pago va aparte, en
//              CobrosDia)
//   sumar    → una venta entregada
//   restar   → una venta anulada (resta lo que sumó y cuenta la anulación)
//
// Restar nunca deja un número negativo y quita las entradas que llegan a 0.
// ═════════════════════════════════════════════════════════════════════════
abstract final class ContadoresVenta {
  /// Tope de productos distintos por día: el resumen es UN documento. Los que
  /// pasan del tope se juntan en «otros».
  static const int maximoPorLista = 250;
  static const String claveOtros = 'otros';
  static const String claveSinPago = 'sin_indicar';

  static AporteVenta aporteDe(Pedido pedido, DateTime momento) {
    final productos = <String, ItemContador>{};
    final variantes = <String, ItemContador>{};
    final combos = <String, ItemContador>{};

    for (final linea in pedido.lineas) {
      if (linea.cantidad <= 0 || linea.productoId.isEmpty) continue;
      final centavos = linea.subtotalCentavos > 0
          ? linea.subtotalCentavos
          : CalculoPedido.subtotalLinea(linea);
      final item = ItemContador(
        nombre: linea.nombre,
        cantidad: linea.cantidad,
        centavos: centavos,
      );
      if (linea.esCombo) {
        _agregar(combos, linea.productoId, item);
        continue;
      }
      _agregar(productos, linea.productoId, item);
      if (linea.modeloId.isNotEmpty) {
        final etiqueta = linea.etiqueta.trim();
        _agregar(
          variantes,
          '${linea.productoId}|${linea.modeloId}|${linea.filaId}',
          ItemContador(
            nombre: etiqueta.isEmpty
                ? linea.nombre
                : '${linea.nombre} · $etiqueta',
            cantidad: linea.cantidad,
            centavos: centavos,
          ),
        );
      }
    }

    return AporteVenta(
      totalCentavos: pedido.totalCentavos,
      esMostrador: pedido.origen == OrigenPedido.mostrador,
      entrega: claveEntrega(pedido),
      hora: claveHora(momento),
      productos: productos,
      variantes: variantes,
      combos: combos,
    );
  }

  /// «Yape » → «yape»; «Tarjeta Visa» → «tarjeta_visa»; «Pago móvil» →
  /// «pago_movil»; vacío → «sin_indicar»; sin letras ni números → «otro».
  /// Antes una forma propia con espacios se juntaba con las demás en «otro».
  static String clavePago(String metodoPago) {
    var limpio = metodoPago.trim().toLowerCase();
    if (limpio.isEmpty) return claveSinPago;
    _sinTildes.forEach((con, sin) => limpio = limpio.replaceAll(con, sin));
    limpio = limpio
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
    if (limpio.length > 30) {
      limpio = limpio.substring(0, 30).replaceAll(RegExp(r'[_-]+$'), '');
    }
    return limpio.isEmpty ? 'otro' : limpio;
  }

  static const _sinTildes = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  static String claveEntrega(Pedido pedido) {
    if (pedido.tipoEntrega == TipoEntrega.delivery) return 'delivery';
    return pedido.enLocal ? 'local' : 'recojo';
  }

  /// Las dos cifras de la hora de Lima: 14:32 → «14».
  static String claveHora(DateTime momento) {
    return ResumenDiaPedidos.horaLima(momento).substring(0, 2);
  }

  static ContadoresDia sumar(ContadoresDia actual, AporteVenta aporte) {
    return ContadoresDia(
      mostradorCentavos:
          actual.mostradorCentavos +
          (aporte.esMostrador ? aporte.totalCentavos : 0),
      mostrador: actual.mostrador + (aporte.esMostrador ? 1 : 0),
      anuladas: actual.anuladas,
      anuladasCentavos: actual.anuladasCentavos,
      // Lo cobrado (porPago) y lo por cobrar los lleva CobrosDia: la plata
      // entra el día en que se cobra, no el día en que se entrega.
      porPago: actual.porPago,
      porCobrarCentavos: actual.porCobrarCentavos,
      porCobrar: actual.porCobrar,
      porEntrega: _sumarClave(
        actual.porEntrega,
        aporte.entrega,
        aporte.totalCentavos,
      ),
      porHora: _sumarClave(actual.porHora, aporte.hora, aporte.totalCentavos),
      porProducto: _sumarItems(actual.porProducto, aporte.productos),
      porVariante: _sumarItems(actual.porVariante, aporte.variantes),
      porCombo: _sumarItems(actual.porCombo, aporte.combos),
    );
  }

  static ContadoresDia restar(ContadoresDia actual, AporteVenta aporte) {
    return ContadoresDia(
      mostradorCentavos: _piso(
        actual.mostradorCentavos -
            (aporte.esMostrador ? aporte.totalCentavos : 0),
      ),
      mostrador: _piso(actual.mostrador - (aporte.esMostrador ? 1 : 0)),
      anuladas: actual.anuladas + 1,
      anuladasCentavos: actual.anuladasCentavos + aporte.totalCentavos,
      porPago: actual.porPago,
      porCobrarCentavos: actual.porCobrarCentavos,
      porCobrar: actual.porCobrar,
      porEntrega: _restarClave(
        actual.porEntrega,
        aporte.entrega,
        aporte.totalCentavos,
      ),
      porHora: _restarClave(actual.porHora, aporte.hora, aporte.totalCentavos),
      porProducto: _restarItems(actual.porProducto, aporte.productos),
      porVariante: _restarItems(actual.porVariante, aporte.variantes),
      porCombo: _restarItems(actual.porCombo, aporte.combos),
    );
  }

  // ── Ayudas ────────────────────────────────────────────────────────────

  static int _piso(int valor) => valor < 0 ? 0 : valor;

  /// Suma [item] en [mapa]; si la misma clave ya estaba (la misma línea dos
  /// veces), junta cantidades y montos.
  static void _agregar(
    Map<String, ItemContador> mapa,
    String clave,
    ItemContador item,
  ) {
    final anterior = mapa[clave];
    mapa[clave] = anterior == null ? item : anterior.mas(item);
  }

  static Map<String, int> _sumarClave(
    Map<String, int> actual,
    String clave,
    int centavos,
  ) {
    if (clave.isEmpty) return actual;
    return {...actual, clave: (actual[clave] ?? 0) + centavos};
  }

  static Map<String, int> _restarClave(
    Map<String, int> actual,
    String clave,
    int centavos,
  ) {
    if (clave.isEmpty || !actual.containsKey(clave)) return actual;
    final nuevo = _piso(actual[clave]! - centavos);
    final copia = {...actual};
    if (nuevo == 0) {
      copia.remove(clave);
    } else {
      copia[clave] = nuevo;
    }
    return copia;
  }

  static Map<String, ItemContador> _sumarItems(
    Map<String, ItemContador> actual,
    Map<String, ItemContador> aporte,
  ) {
    if (aporte.isEmpty) return actual;
    final copia = {...actual};
    for (final entrada in aporte.entries) {
      var clave = entrada.key;
      // Un día con demasiados productos distintos junta el resto en «otros».
      if (!copia.containsKey(clave) && copia.length >= maximoPorLista) {
        clave = claveOtros;
      }
      final anterior = copia[clave];
      if (clave == claveOtros) {
        // «Otros» conserva su nombre aunque se junten productos distintos.
        copia[clave] = ItemContador(
          nombre: 'Otros',
          cantidad: (anterior?.cantidad ?? 0) + entrada.value.cantidad,
          centavos: (anterior?.centavos ?? 0) + entrada.value.centavos,
        );
        continue;
      }
      copia[clave] = anterior == null
          ? entrada.value
          : anterior.mas(entrada.value);
    }
    return copia;
  }

  static Map<String, ItemContador> _restarItems(
    Map<String, ItemContador> actual,
    Map<String, ItemContador> aporte,
  ) {
    if (aporte.isEmpty) return actual;
    final copia = {...actual};
    for (final entrada in aporte.entries) {
      var clave = entrada.key;
      if (!copia.containsKey(clave)) {
        // Estaba junto en «otros» (pasó del tope ese día).
        if (!copia.containsKey(claveOtros)) continue;
        clave = claveOtros;
      }
      final anterior = copia[clave]!;
      final restado = ItemContador(
        nombre: anterior.nombre,
        cantidad: _piso(anterior.cantidad - entrada.value.cantidad),
        centavos: _piso(anterior.centavos - entrada.value.centavos),
      );
      if (restado.vacio) {
        copia.remove(clave);
      } else {
        copia[clave] = restado;
      }
    }
    return copia;
  }
}
