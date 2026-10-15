import 'package:flutter/widgets.dart';

import '../../../negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../application/services/entrada_numerica.dart';
import '../../application/services/lectura_unidades_producto.dart';
import '../../application/services/vista_previa_medida.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/producto.dart';
import '../../domain/models/regla_venta_medida.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioMedidaController
// ═════════════════════════════════════════════════════════════════════════
// Estado del modo "Por medida" del formulario de producto: qué se mide, en
// qué unidad, el precio (por 1 unidad o por otra cantidad), el stock, la
// regla de venta (la del negocio o una propia) y la vista previa del
// cliente. Lo usa FormularioProductoController.
//
// REGLAS:
//   - El stock se escribe en la unidad visual (kg, L…) con decimales y se
//     guarda entero en unidad base (g, ml). Mínimo e incremento nunca
//     bloquean el stock.
//   - Por defecto el precio cubre 1 unidad de la medida (S/ 4.50 por kg).
//   - Con una sola medida activa, "Qué mides" se elige solo.
// ═════════════════════════════════════════════════════════════════════════
class FormularioMedidaController extends ChangeNotifier {
  FormularioMedidaController({required this.medidasActivas});

  /// Medidas activas del catálogo del negocio (siempre al día).
  final List<MedidaVentaPersistida> Function() medidasActivas;

  final TextEditingController precioCtrl = TextEditingController();
  final TextEditingController referenciaCtrl = TextEditingController();
  final TextEditingController stockCtrl = TextEditingController();
  final TextEditingController minimoCtrl = TextEditingController();
  final TextEditingController incrementoCtrl = TextEditingController();

  FamiliaUnidad? familia;
  String unidad = '';

  /// true: el precio cubre 1 unidad de la medida (S/ 4.50 por kg).
  /// false: "otra cantidad" escrita en [referenciaCtrl] (S/ 1.20 por 250 g).
  bool precioPorUnidad = true;

  /// true: el producto usa su propio mínimo e incremento.
  bool reglaPropia = false;

  /// Precarga desde un producto guardado por medida.
  void precargar(Producto producto) {
    familia = producto.medidaFamilia;
    unidad = producto.medidaUnidad;
    final factor = LecturaUnidadesProducto.factorDe(unidad);
    if (producto.cantidadReferenciaBase > 0 && factor > 0) {
      precioPorUnidad = producto.cantidadReferenciaBase == factor;
      referenciaCtrl.text = baseATextoVisual(
        producto.cantidadReferenciaBase,
        factor,
      );
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

  /// Con una sola medida activa no hay nada que elegir en "Qué mides".
  void sugerirFamilia() {
    if (familia != null) return;
    final familias = medidasActivas().map((medida) => medida.familia!).toSet();
    if (familias.length == 1) _aplicarFamilia(familias.single);
  }

  // ── Datos derivados ───────────────────────────────────────────────────

  String get unidadBaseNombre =>
      familia == null ? '' : RegistroUnidades.baseDe(familia!).nombre;

  /// Medida activa del negocio para la familia elegida.
  MedidaVentaPersistida? get medidaDelNegocio {
    for (final medida in medidasActivas()) {
      if (medida.familia == familia) return medida;
    }
    return null;
  }

  int? get precioCentavos => textoACentavos(precioCtrl.text);

  /// Cantidad que cubre el precio: 1 unidad de la medida (1 kg = 1000 g) o
  /// la "otra cantidad" escrita.
  ConversionCantidad? get referencia {
    if (!precioPorUnidad) return _convertir(referenciaCtrl.text);
    final factor = LecturaUnidadesProducto.factorDe(unidad);
    return factor > 0 ? ConversionCantidad.valida(factor) : null;
  }

  ConversionCantidad? get stock => _convertir(stockCtrl.text);

  ConversionCantidad? _convertir(String texto) {
    if (texto.trim().isEmpty) return null;
    final factor = LecturaUnidadesProducto.factorDe(unidad);
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
    if (!precioPorUnidad && referenciaCtrl.text.trim().isNotEmpty) {
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

  /// "S/ 1.20 por 250 g": solo cuando el precio cubre otra cantidad.
  String get resumenPrecio {
    if (precioPorUnidad) return '';
    final factor = LecturaUnidadesProducto.factorDe(unidad);
    final centavos = precioCentavos;
    final ref = referencia;
    if (factor <= 0 || centavos == null || centavos <= 0) return '';
    if (ref == null || !ref.esValida) return '';
    return 'S/ ${centavosATexto(centavos)} por '
        '${baseATextoVisual(ref.base!, factor)} $unidad';
  }

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
    final unidadVisual = LecturaUnidadesProducto.unidadRegistrada(unidad);
    final medida = medidaDelNegocio;
    if (regla == null || unidadVisual == null || medida == null) {
      return const [];
    }
    return VistaPreviaMedida.cantidadesRapidas(
      regla,
      unidadVisual,
      medida.cantidadesRapidasBase,
    );
  }

  /// Ejemplo de pedido por monto (S/ 2.00); null si no se vende por monto.
  PedidoPorMonto? get pedidoPorMontoEjemplo {
    final regla = _regla;
    final unidadVisual = LecturaUnidadesProducto.unidadRegistrada(unidad);
    if (regla == null || unidadVisual == null) return null;
    return VistaPreviaMedida.porMonto(regla, unidadVisual);
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
  }

  void cambiarUnidad(String nueva) {
    unidad = nueva;
    notifyListeners();
  }

  void cambiarPrecioPorUnidad(bool porUnidad) {
    precioPorUnidad = porUnidad;
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
