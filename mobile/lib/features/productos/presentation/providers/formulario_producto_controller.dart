import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../../negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../../negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import '../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../application/services/constructor_producto.dart';
import '../../application/services/lectura_unidades_producto.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/modo_venta.dart';
import '../../domain/models/producto.dart';
import '../widgets/formulario/medida_entrada.dart';
import '../widgets/formulario/seccion_presentacion_producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioProductoController
// ═════════════════════════════════════════════════════════════════════════
// Estado del formulario de producto: campos, modo de venta, presentación,
// medida, foto elegida y validaciones. El widget solo lo dibuja; el armado
// del Producto lo hace ConstructorProducto.
//
// REGLAS DE PRODUCTO:
//   1. El selector de modo solo deja elegir los modos ACTIVOS del catálogo.
//   2. En medida, el stock se escribe en la unidad visual (kg, L…) con
//      decimales y se convierte a entero en unidad base (g, ml). El mínimo
//      y el incremento NUNCA bloquean: son informativos.
//   3. Un solo campo de precio por modo: precio por presentación, o precio
//      de la cantidad de referencia en medida.
//   4. Los productos legacy (sin presentacionId) NO están obligados a
//      migrar: se guardan Como Están. Migrar es obligatorio solo para
//      productos nuevos o cuando la persona completa la sección del modo.
// ═════════════════════════════════════════════════════════════════════════
class FormularioProductoController extends ChangeNotifier {
  FormularioProductoController({
    required this.producto,
    required this.categoriasDisponibles,
    required this.catalogoVenta,
  }) {
    nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    descripcionCtrl = TextEditingController(text: producto?.descripcion ?? '');
    stockPresentacionCtrl = TextEditingController(
      text: (producto?.stock ?? 0) > 0 ? producto!.stock.toString() : '',
    );
    precioPresentacionCtrl = TextEditingController(
      text: (producto?.precio ?? 0) > 0
          ? centavosATexto(producto!.precioCentavos)
          : '',
    );
    esStockInfinito = producto?.esStockInfinito ?? false;
    tieneDelivery = producto?.tieneDelivery ?? true;
    urlImagenActual = producto?.urlImagen ?? '';
    _precargarDesde(producto);
  }

  /// Producto editado (null si es nuevo).
  final Producto? producto;
  final List<String> categoriasDisponibles;

  /// Catálogo de venta del negocio. Puede llegar después (reintento): el
  /// widget lo actualiza al reconstruirse, sin volver a precargar.
  CatalogoVentaPersistido? catalogoVenta;

  late final TextEditingController nombreCtrl;
  late final TextEditingController descripcionCtrl;
  late final TextEditingController stockPresentacionCtrl;
  late final TextEditingController precioPresentacionCtrl;
  final TextEditingController precioMedidaCtrl = TextEditingController();
  final TextEditingController referenciaCtrl = TextEditingController();
  final TextEditingController stockMedidaCtrl = TextEditingController();

  late bool esStockInfinito;
  late bool tieneDelivery;
  String categoria = '';

  ModoVenta? modoVista;
  String presentacionId = '';
  String formatoEtiqueta = '';
  FormatoElegido? formato;
  FamiliaUnidad? medidaFamilia;
  String medidaUnidad = '';

  String urlImagenActual = '';
  XFile? fotoNueva;
  Uint8List? fotoNuevaBytes;
  bool _guardando = false;

  bool get esNuevo => producto == null;
  bool get guardando => _guardando;

  set guardando(bool valor) {
    _guardando = valor;
    notifyListeners();
  }

  /// Precarga el formulario desde el producto editado. Nunca migra datos:
  /// solo muestra lo que había y sugiere el modo cuando la etiqueta legacy
  /// es una unidad de medida (kg, L…).
  void _precargarDesde(Producto? producto) {
    // La categoría guardada manda; si está vacía se usa la primera
    // disponible (el ?? no sirve: '' no es null).
    final categoriaGuardada = producto?.categoria.trim() ?? '';
    categoria = categoriaGuardada.isNotEmpty
        ? categoriaGuardada
        : (categoriasDisponibles.isNotEmpty ? categoriasDisponibles.first : '');

    if (producto == null) {
      modoVista = modosDisponibles.isEmpty ? null : modosDisponibles.first;
      return;
    }

    if (producto.esPorMedida) {
      modoVista = ModoVenta.medida;
      medidaFamilia = producto.medidaFamilia;
      medidaUnidad = producto.medidaUnidad;
      final factor = LecturaUnidadesProducto.factorDe(medidaUnidad);
      if (producto.cantidadReferenciaBase > 0 && factor > 0) {
        referenciaCtrl.text = baseATextoVisual(
          producto.cantidadReferenciaBase,
          factor,
        );
      }
      if (producto.precioCentavos > 0) {
        precioMedidaCtrl.text = centavosATexto(producto.precioCentavos);
      }
      final stockBase = producto.stockBase;
      if (stockBase != null && stockBase > 0 && factor > 0) {
        stockMedidaCtrl.text = baseATextoVisual(stockBase, factor);
      }
      return;
    }

    modoVista = ModoVenta.presentacion;
    presentacionId = producto.presentacionId;
    if (presentacionId.isNotEmpty && producto.formatoValorBase > 0) {
      final etiqueta = LecturaUnidadesProducto.etiquetaFormatoGuardado(
        producto,
        presentacionesActivas,
      );
      formatoEtiqueta = etiqueta ?? '';
      formato = FormatoElegido(
        valorBase: producto.formatoValorBase,
        familia: producto.formatoFamilia?.name ?? '',
        unidad: producto.formatoUnidad,
      );
    }

    // Etiqueta legacy tipo kg/g/L/ml: se SUGIERE el modo medida, sin
    // migrar nada (los campos de medida quedan vacíos a propósito).
    if (presentacionId.isEmpty &&
        LecturaUnidadesProducto.esUnidadDeMedida(producto.etiquetaUnidad)) {
      modoVista = ModoVenta.medida;
      medidaUnidad = producto.etiquetaUnidad;
    }
  }

  // ── Catálogo ──────────────────────────────────────────────────────────

  List<OpcionPresentacion> get presentacionesActivas =>
      (catalogoVenta?.presentaciones ?? const <OpcionPresentacion>[])
          .where((presentacion) => presentacion.activa)
          .toList();

  List<MedidaVentaPersistida> get medidasActivas =>
      (catalogoVenta?.medidas ?? const <MedidaVentaPersistida>[])
          .where((medida) => medida.activa && medida.familia != null)
          .toList();

  List<ModoVenta> get modosDisponibles {
    final modos = <ModoVenta>[];
    if (presentacionesActivas.isNotEmpty) modos.add(ModoVenta.presentacion);
    if (medidasActivas.isNotEmpty) modos.add(ModoVenta.medida);
    return modos;
  }

  List<String> get categoriasEfectivas {
    final categorias = <String>{...categoriasDisponibles};
    final categoriaGuardada = producto?.categoria ?? '';
    if (categoriaGuardada.trim().isNotEmpty) categorias.add(categoriaGuardada);
    return categorias.toList();
  }

  String get etiquetaLegacy => LecturaUnidadesProducto.etiquetaLegacy(producto);

  String get _unidadBaseNombre => medidaFamilia == null
      ? ''
      : RegistroUnidades.baseDe(medidaFamilia!).nombre;

  // ── Estado derivado ───────────────────────────────────────────────────

  bool get presentacionCompleta {
    if (presentacionId.isEmpty || formato == null) return false;
    final presentaciones = presentacionesActivas.where(
      (presentacion) => presentacion.id == presentacionId,
    );
    if (presentaciones.isEmpty) return false;
    final elegido = formato!;
    return presentaciones.first.formatos.any(
      (candidato) =>
          candidato.valorBase == elegido.valorBase &&
          candidato.familia.name == elegido.familia &&
          candidato.unidadVisible.nombre == elegido.unidad,
    );
  }

  ConversionCantidad? get referencia => _convertir(referenciaCtrl.text);

  ConversionCantidad? get stockMedida => _convertir(stockMedidaCtrl.text);

  ConversionCantidad? _convertir(String texto) {
    if (texto.trim().isEmpty) return null;
    final factor = LecturaUnidadesProducto.factorDe(medidaUnidad);
    if (factor <= 0) return null;
    return textoAUnidadBase(texto, factor, unidadBase: _unidadBaseNombre);
  }

  bool get medidaCompleta {
    if (medidaFamilia == null || medidaUnidad.isEmpty) return false;
    final ref = referencia;
    if (ref == null || !ref.esValida) return false;
    final centavos = textoACentavos(precioMedidaCtrl.text);
    if (centavos == null || centavos <= 0) return false;
    if (esStockInfinito) return true;
    final stock = stockMedida;
    return stock != null && stock.esValida;
  }

  String get resumenPrecioMedida {
    final factor = LecturaUnidadesProducto.factorDe(medidaUnidad);
    final centavos = textoACentavos(precioMedidaCtrl.text);
    final ref = referencia;
    if (factor <= 0 || centavos == null || centavos <= 0) return '';
    if (ref == null || !ref.esValida) return '';
    return 'S/ ${centavosATexto(centavos)} por '
        '${baseATextoVisual(ref.base!, factor)} $medidaUnidad';
  }

  int? get precioVisibleCentavos {
    if (modoVista == ModoVenta.medida) {
      return textoACentavos(precioMedidaCtrl.text);
    }
    return textoACentavos(precioPresentacionCtrl.text);
  }

  bool get _stockPresentacionValido =>
      esStockInfinito || (int.tryParse(stockPresentacionCtrl.text) ?? -1) >= 0;

  /// Lo visible en la vista de medida es coherente: lo escrito, si hay algo
  /// escrito, convierte. Un valor inválido (ej. una cantidad que truncada
  /// da cero) bloquea aunque el producto sea legacy: "rechazar con mensaje".
  /// Los campos vacíos, en cambio, permiten guardar sin migrar.
  bool get _medidaVistaValida {
    if (precioMedidaCtrl.text.trim().isNotEmpty) {
      final centavos = textoACentavos(precioMedidaCtrl.text);
      if (centavos == null || centavos <= 0) return false;
    }
    if (referenciaCtrl.text.trim().isNotEmpty) {
      final ref = referencia;
      if (ref == null || !ref.esValida) return false;
    }
    if (!esStockInfinito && stockMedidaCtrl.text.trim().isNotEmpty) {
      final stock = stockMedida;
      if (stock == null || !stock.esValida) return false;
    }
    return true;
  }

  bool get camposOk {
    if (_guardando) return false;
    if (nombreCtrl.text.trim().isEmpty) return false;
    if (categoria.isEmpty) return false;

    if (modoVista == ModoVenta.medida) {
      if (!_medidaVistaValida) return false;
      if (medidaCompleta) return true;
      // Legacy sin migrar: se puede guardar (regla 4).
      return !esNuevo;
    }

    final centavos = precioVisibleCentavos;
    if (centavos == null || centavos <= 0) return false;
    if (!_stockPresentacionValido) return false;
    if (presentacionCompleta) return true;
    // Legacy sin presentación: se puede guardar (regla 4).
    return !esNuevo;
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  /// Se llama al cambiar un texto: recalcula si Guardar se habilita.
  void trasCambioTexto() => notifyListeners();

  void cambiarCategoria(String valor) {
    categoria = valor;
    notifyListeners();
  }

  void cambiarModo(ModoVenta modo) {
    modoVista = modo;
    notifyListeners();
  }

  void cambiarPresentacion(String id) {
    presentacionId = id;
    formato = null;
    formatoEtiqueta = '';
    final presentaciones = presentacionesActivas.where(
      (presentacion) => presentacion.id == id,
    );
    if (presentaciones.isNotEmpty) {
      final formatos = presentaciones.first.formatos;
      if (formatos.length == 1) {
        formatoEtiqueta = formatos.first.etiqueta;
        formato = FormatoElegido(
          valorBase: formatos.first.valorBase,
          familia: formatos.first.familia.name,
          unidad: formatos.first.unidadVisible.nombre,
        );
      }
    }
    notifyListeners();
  }

  void cambiarFormato(FormatoElegido elegido) {
    formato = elegido;
    formatoEtiqueta = LecturaUnidadesProducto.etiquetaDeFormato(
      valorBase: elegido.valorBase,
      familiaNombre: elegido.familia,
      unidadNombre: elegido.unidad,
    );
    notifyListeners();
  }

  void cambiarFamilia(FamiliaUnidad familia) {
    medidaFamilia = familia;
    final activas = medidasActivas
        .where((medida) => medida.familia == familia)
        .toList();
    medidaUnidad = activas.isEmpty
        ? ''
        : (activas.first.unidadVisual?.nombre ?? '');
    notifyListeners();
  }

  void cambiarUnidadMedida(String unidad) {
    medidaUnidad = unidad;
    notifyListeners();
  }

  void cambiarStockInfinito(bool valor) {
    esStockInfinito = valor;
    notifyListeners();
  }

  void cambiarDelivery(bool valor) {
    tieneDelivery = valor;
    notifyListeners();
  }

  void elegirFoto(XFile archivo, Uint8List bytes) {
    fotoNueva = archivo;
    fotoNuevaBytes = bytes;
    notifyListeners();
  }

  /// Arma el Producto con lo escrito (ConstructorProducto).
  Producto construirProducto() {
    final elegido = formato;
    return ConstructorProducto.construir(
      DatosFormularioProducto(
        anterior: producto,
        nombre: nombreCtrl.text.trim(),
        descripcion: descripcionCtrl.text.trim(),
        categoria: categoria,
        tieneDelivery: tieneDelivery,
        urlImagen: urlImagenActual,
        esStockInfinito: esStockInfinito,
        modo: modoVista,
        medidaCompleta: medidaCompleta,
        medidaFamilia: medidaFamilia,
        medidaUnidad: medidaUnidad,
        referenciaBase: referencia?.base,
        precioMedidaCentavos: textoACentavos(precioMedidaCtrl.text),
        stockMedidaBase: stockMedida?.base,
        presentacionCompleta: presentacionCompleta,
        presentacionId: presentacionId,
        formatoValorBase: elegido?.valorBase ?? 0,
        formatoFamilia: elegido?.familia ?? '',
        formatoUnidad: elegido?.unidad ?? '',
        precioPresentacionCentavos: textoACentavos(precioPresentacionCtrl.text),
        stockPresentacion: int.tryParse(stockPresentacionCtrl.text) ?? 0,
        precioVisibleCentavos: precioVisibleCentavos,
      ),
    );
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    descripcionCtrl.dispose();
    stockPresentacionCtrl.dispose();
    precioPresentacionCtrl.dispose();
    precioMedidaCtrl.dispose();
    referenciaCtrl.dispose();
    stockMedidaCtrl.dispose();
    super.dispose();
  }
}
