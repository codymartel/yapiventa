import 'package:flutter/widgets.dart';

import '../../../negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../application/services/cantidades_tipicas.dart';
import '../../application/services/entrada_numerica.dart';
import '../../application/services/lectura_unidades_producto.dart';
import '../../application/services/vista_previa_medida.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/producto.dart';
import '../../domain/models/regla_venta_medida.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioMedidaController
// ═════════════════════════════════════════════════════════════════════════
// Estado del modo "Por medida" del formulario de producto: qué se mide, el
// precio y la cantidad que cubre ("S/ 3.00 por ¼ kg"), el stock, la regla de
// venta (la del negocio o una propia) y la vista previa del cliente. Lo usa
// FormularioProductoController.
//
// REGLAS:
//   - La unidad del producto NO se elige acá: es la unidad habitual que el
//     negocio configuró para esa medida (Configuración → Medidas).
//   - El stock se escribe en esa unidad (kg, L…) con decimales y se guarda
//     entero en unidad base (g, ml). Mínimo e incremento nunca lo bloquean.
//   - "Por" elige una cantidad típica (1 kg, ½ kg, ¼ kg, 100 g) o "Otra
//     cantidad", con su propia unidad. Se guarda lo que el vendedor escribió,
//     nunca convertido; la equivalencia por kg solo se muestra.
//   - Con una sola medida activa, "Qué mides" se elige solo.
//   - Si la medida del producto se desactivó después, el producto conserva su
//     familia y su unidad: nada se borra ni cambia solo.
// ═════════════════════════════════════════════════════════════════════════
class FormularioMedidaController extends ChangeNotifier {
  FormularioMedidaController({
    required this.medidasActivas,
    required this.medidasDelCatalogo,
  });

  /// Medidas activas del catálogo del negocio (siempre al día).
  final List<MedidaVentaPersistida> Function() medidasActivas;

  /// Todas las medidas del catálogo, activas o no: la regla de un producto
  /// cuya medida se desactivó se sigue leyendo de acá.
  final List<MedidaVentaPersistida> Function() medidasDelCatalogo;

  final TextEditingController precioCtrl = TextEditingController();
  final TextEditingController referenciaCtrl = TextEditingController();
  final TextEditingController stockCtrl = TextEditingController();
  final TextEditingController minimoCtrl = TextEditingController();
  final TextEditingController incrementoCtrl = TextEditingController();

  FamiliaUnidad? familia;

  /// Unidad habitual del producto (kg, L…): la del stock y la que se congela
  /// en el producto.
  String unidad = '';

  /// Cantidad típica elegida en "Por" (en unidad base). 0 = sin familia.
  int porBase = 0;

  /// true: "Por" es "Otra cantidad", escrita en [referenciaCtrl] con
  /// [unidadOtra] (S/ 1.20 por 250 g).
  bool otraCantidad = false;
  String unidadOtra = '';

  /// true: el producto usa su propio mínimo e incremento.
  bool reglaPropia = false;

  /// Precarga desde un producto guardado por medida.
  void precargar(Producto producto) {
    familia = producto.medidaFamilia;
    unidad = producto.medidaUnidad;
    unidadOtra = unidad;
    final factor = LecturaUnidadesProducto.factorDe(unidad);
    final elegida = familia;
    if (elegida != null) {
      final referencia = producto.cantidadReferenciaBase;
      if (referencia > 0) {
        _precargarReferencia(elegida, referencia);
      } else {
        _elegirPorDefecto(elegida);
      }
    }
    final minimo = producto.minimoBase;
    final incremento = producto.incrementoBase;
    if (minimo != null && incremento != null) {
      reglaPropia = true;
      minimoCtrl.text = '$minimo';
      incrementoCtrl.text = '$incremento';
    }
    if (producto.precioCentavos > 0) {
      precioCtrl.text = centavosATexto(producto.precioCentavos);
    }
    final stockBase = producto.stockBase;
    if (stockBase != null && stockBase > 0 && factor > 0) {
      stockCtrl.text = baseATextoVisual(stockBase, factor);
    }
  }

  /// Una cantidad guardada que está en el menú se elige ahí; si no, abre en
  /// "Otra cantidad" con la unidad en que se lee entera (300 g, 2 kg).
  void _precargarReferencia(FamiliaUnidad elegida, int referencia) {
    if (CantidadesTipicas.coincidente(elegida, referencia) != null) {
      porBase = referencia;
      return;
    }
    final natural = CantidadesTipicas.unidadNatural(elegida, referencia);
    otraCantidad = true;
    unidadOtra = natural.nombre;
    referenciaCtrl.text = baseATextoVisual(referencia, natural.factorBase);
  }

  void _elegirPorDefecto(FamiliaUnidad elegida) {
    final tipicas = CantidadesTipicas.de(elegida);
    porBase = tipicas.isEmpty ? 0 : tipicas.first.base;
  }

  /// Con una sola medida activa no hay nada que elegir en "Qué mides".
  void sugerirFamilia() {
    if (familia != null) return;
    final familias = medidasActivas().map((medida) => medida.familia!).toSet();
    if (familias.length == 1) _aplicarFamilia(familias.single);
  }

  // ── Datos derivados ───────────────────────────────────────────────────

  String get unidadBaseNombre =>
      familia == null ? '' : RegistroUnidades.baseDe(familia!).nombre;

  /// Medida del catálogo para la familia elegida, esté activa o no.
  MedidaVentaPersistida? get medidaDelNegocio {
    for (final medida in medidasDelCatalogo()) {
      if (medida.familia == familia) return medida;
    }
    return null;
  }

  /// true si el producto editado usa una medida que el negocio desactivó.
  bool get familiaDesactivada {
    final elegida = familia;
    if (elegida == null) return false;
    return !medidasActivas().any((medida) => medida.familia == elegida);
  }

  /// Opciones del menú "Por" de la familia elegida.
  List<CantidadTipica> get opcionesPor =>
      familia == null ? const [] : CantidadesTipicas.de(familia!);

  int? get precioCentavos => textoACentavos(precioCtrl.text);

  /// Cantidad que cubre el precio: la elegida en el menú o la "otra cantidad"
  /// escrita.
  ConversionCantidad? get referencia {
    if (otraCantidad) return _convertir(referenciaCtrl.text, unidadOtra);
    return porBase > 0 ? ConversionCantidad.valida(porBase) : null;
  }

  ConversionCantidad? get stock => _convertir(stockCtrl.text, unidad);

  ConversionCantidad? _convertir(String texto, String unidadNombre) {
    if (texto.trim().isEmpty) return null;
    final factor = LecturaUnidadesProducto.factorDe(unidadNombre);
    if (factor <= 0) return null;
    return textoAUnidadBase(texto, factor, unidadBase: unidadBaseNombre);
  }

  int? get minimoPropio => _enteroPositivo(minimoCtrl.text);
  int? get incrementoPropio => _enteroPositivo(incrementoCtrl.text);

  static int? _enteroPositivo(String texto) {
    final valor = int.tryParse(texto.trim());
    return valor != null && valor > 0 ? valor : null;
  }

  /// Mínimo e incremento que rigen: los propios o los de la medida.
  int get minimoEfectivo =>
      (reglaPropia ? minimoPropio : medidaDelNegocio?.minimoBase) ?? 0;
  int get incrementoEfectivo =>
      (reglaPropia ? incrementoPropio : medidaDelNegocio?.incrementoBase) ?? 0;

  /// Todo lo necesario para guardar un producto por medida.
  bool completa({required bool stockInfinito}) {
    if (familia == null || unidad.isEmpty) return false;
    final ref = referencia;
    if (ref == null || !ref.esValida) return false;
    final centavos = precioCentavos;
    if (centavos == null || centavos <= 0) return false;
    if (reglaPropia && (minimoPropio == null || incrementoPropio == null)) {
      return false;
    }
    if (stockInfinito) return true;
    final cantidad = stock;
    return cantidad != null && cantidad.esValida;
  }

  /// Lo escrito es coherente: lo que hay escrito convierte. Un valor
  /// inválido bloquea aunque el producto sea legacy; los campos vacíos, en
  /// cambio, permiten guardar sin migrar.
  bool vistaValida({required bool stockInfinito}) {
    if (precioCtrl.text.trim().isNotEmpty) {
      final centavos = precioCentavos;
      if (centavos == null || centavos <= 0) return false;
    }
    if (otraCantidad && referenciaCtrl.text.trim().isNotEmpty) {
      final ref = referencia;
      if (ref == null || !ref.esValida) return false;
    }
    if (reglaPropia && (minimoPropio == null || incrementoPropio == null)) {
      return false;
    }
    if (!stockInfinito && stockCtrl.text.trim().isNotEmpty) {
      final cantidad = stock;
      if (cantidad == null || !cantidad.esValida) return false;
    }
    return true;
  }

  /// Lo primero que impide guardar, para decírselo a la persona: "Falta: …"
  /// si no está escrito, "Revisa: …" si está mal escrito. null si no hay
  /// nada. Con [exigirTodo] false (producto antiguo sin migrar) los campos
  /// vacíos no cuentan; los mal escritos sí.
  String? queFalta({required bool stockInfinito, required bool exigirTodo}) {
    if (exigirTodo && familia == null) return 'Falta: qué mides';

    final precio = precioCtrl.text.trim();
    if (precio.isEmpty) {
      if (exigirTodo) return 'Falta: precio';
    } else if ((precioCentavos ?? 0) <= 0) {
      return 'Revisa: precio';
    }

    if (otraCantidad) {
      final texto = referenciaCtrl.text.trim();
      if (texto.isEmpty) {
        if (exigirTodo) return 'Falta: cantidad de «Otra cantidad»';
      } else if (!(referencia?.esValida ?? false)) {
        return 'Revisa: cantidad de «Otra cantidad»';
      }
    }

    if (!stockInfinito) {
      final texto = stockCtrl.text.trim();
      if (texto.isEmpty) {
        if (exigirTodo) return 'Falta: stock';
      } else if (!(stock?.esValida ?? false)) {
        return 'Revisa: stock';
      }
    }

    if (reglaPropia && (minimoPropio == null || incrementoPropio == null)) {
      return 'Falta: mínimo e incremento propios';
    }
    return null;
  }

  /// Cuánto sale el kg (o L, m, m²) con el precio escrito: "= S/ 12.00 por
  /// kg", o "≈" si la cuenta no es exacta (se muestra hacia abajo). Vacío si
  /// el precio ya es por esa unidad o falta algo.
  String get equivalencia {
    final elegida = familia;
    final centavos = precioCentavos;
    final ref = referencia;
    if (elegida == null || centavos == null || centavos <= 0) return '';
    if (ref == null || !ref.esValida) return '';
    final grande = CantidadesTipicas.unidadGrande(elegida);
    if (ref.base == grande.factorBase) return '';
    final porGrande = centavos * grande.factorBase;
    final signo = porGrande % ref.base! == 0 ? '=' : '≈';
    return '$signo S/ ${centavosATexto(porGrande ~/ ref.base!)} '
        'por ${grande.nombre}';
  }

  /// "Otra cantidad" es donde se cuelan los errores (S/ 12 por 1 g): la
  /// equivalencia se destaca como aviso.
  bool get equivalenciaEsAlarma => otraCantidad && equivalencia.isNotEmpty;

  // ── Vista previa del cliente ──────────────────────────────────────────

  ReglaVentaMedida? get _regla {
    final familiaElegida = familia;
    final ref = referencia;
    final centavos = precioCentavos;
    if (familiaElegida == null || ref == null || !ref.esValida) return null;
    if (centavos == null) return null;
    return VistaPreviaMedida.regla(
      familia: familiaElegida,
      precioCentavos: centavos,
      referenciaBase: ref.base!,
      minimoBase: minimoEfectivo,
      incrementoBase: incrementoEfectivo,
      permiteMonto: medidaDelNegocio?.permiteMonto ?? false,
    );
  }

  /// Precio de cada cantidad rápida, como lo verá el cliente.
  List<CantidadRapidaConPrecio> get cantidadesRapidasConPrecio {
    final regla = _regla;
    final medida = medidaDelNegocio;
    if (regla == null || medida == null) return const [];
    return VistaPreviaMedida.cantidadesRapidas(
      regla,
      medida.cantidadesRapidasBase,
    );
  }

  /// Ejemplo de pedido por monto (S/ 2.00); null si no se vende por monto.
  PedidoPorMonto? get pedidoPorMontoEjemplo {
    final regla = _regla;
    if (regla == null) return null;
    return VistaPreviaMedida.porMonto(regla);
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  void trasCambioTexto() => notifyListeners();

  void cambiarFamilia(FamiliaUnidad nueva) {
    _aplicarFamilia(nueva);
    notifyListeners();
  }

  void _aplicarFamilia(FamiliaUnidad nueva) {
    familia = nueva;
    final activas = medidasActivas()
        .where((medida) => medida.familia == nueva)
        .toList();
    unidad = activas.isEmpty ? '' : (activas.first.unidadVisual?.nombre ?? '');
    unidadOtra = unidad;
    otraCantidad = false;
    referenciaCtrl.clear();
    _elegirPorDefecto(nueva);
  }

  /// Elige una cantidad típica del menú "Por".
  void cambiarPor(int base) {
    porBase = base;
    otraCantidad = false;
    notifyListeners();
  }

  void elegirOtraCantidad() {
    otraCantidad = true;
    notifyListeners();
  }

  void cambiarUnidadOtra(String nueva) {
    unidadOtra = nueva;
    notifyListeners();
  }

  /// Al personalizar se parte de la regla de la medida del negocio.
  void cambiarReglaPropia(bool propia) {
    reglaPropia = propia;
    if (propia && minimoCtrl.text.isEmpty && incrementoCtrl.text.isEmpty) {
      final medida = medidaDelNegocio;
      if (medida != null) {
        minimoCtrl.text = '${medida.minimoBase}';
        incrementoCtrl.text = '${medida.incrementoBase}';
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    precioCtrl.dispose();
    referenciaCtrl.dispose();
    stockCtrl.dispose();
    minimoCtrl.dispose();
    incrementoCtrl.dispose();
    super.dispose();
  }
}
