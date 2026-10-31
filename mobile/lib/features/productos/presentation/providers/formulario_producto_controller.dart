import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../../negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../../negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import '../../../negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import '../../application/services/constructor_producto.dart';
import '../../application/services/entrada_numerica.dart';
import '../../application/services/lectura_unidades_producto.dart';
import '../../application/services/sugerencias_combo.dart';
import '../../application/services/sugerencias_extras.dart';
import '../../application/services/sugerencias_modelos.dart';
import '../../domain/models/foto_nueva.dart';
import '../../domain/models/formato_elegido.dart';
import '../../domain/models/modo_venta.dart';
import '../../domain/models/producto.dart';
import 'formulario_combo_controller.dart';
import 'formulario_extras_controller.dart';
import 'formulario_medida_controller.dart';
import 'formulario_modelos_controller.dart';
import 'formulario_presentacion_controller.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioProductoController
// ═════════════════════════════════════════════════════════════════════════
// Estado del formulario de producto: campos comunes, modo de venta,
// presentación, foto elegida y validaciones. Lo del modo "Por medida" vive
// en [medida] (FormularioMedidaController). El widget solo lo dibuja; el
// armado del Producto lo hace ConstructorProducto.
//
// REGLAS DE PRODUCTO:
//   1. El selector de modo solo deja elegir los modos ACTIVOS del catálogo.
//   2. Producto nuevo: la primera presentación activa (orden del preset del
//      rubro) y la única medida activa vienen elegidas.
//   3. Un solo campo de precio por modo: por presentación, o por cantidad
//      de referencia en medida.
//   4. Los productos legacy (sin presentacionId) NO están obligados a
//      migrar: se guardan Como Están. Migrar es obligatorio solo para
//      productos nuevos o cuando la persona completa la sección del modo.
//   5. Con variables ([modelos].usa) el precio y el stock se escriben en las
//      filas de cada modelo, no en los campos simples del modo.
// ═════════════════════════════════════════════════════════════════════════
class FormularioProductoController extends ChangeNotifier {
  FormularioProductoController({
    required this.producto,
    required this.categoriasDisponibles,
    required this.catalogoVenta,
    this.rubro = '',
    this.productosParaCombo = const [],
  }) {
    nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    descripcionCtrl = TextEditingController(text: producto?.descripcion ?? '');
    presentacion = FormularioPresentacionController(
      presentacionesActivas: () => presentacionesActivas,
      alCambiarPresentacion: () => modelos.limpiarFormatos(),
      precio: (producto?.precio ?? 0) > 0
          ? centavosATexto(producto!.precioCentavos)
          : '',
      stock: (producto?.stock ?? 0) > 0 ? producto!.stock.toString() : '',
    );
    esStockInfinito = producto?.esStockInfinito ?? false;
    tieneDelivery = producto?.tieneDelivery ?? true;
    urlImagenActual = producto?.urlImagen ?? '';
    medida = FormularioMedidaController(
      medidasActivas: () => medidasActivas,
      medidasDelCatalogo: () => medidasDelCatalogo,
    )..addListener(notifyListeners);
    modelos =
        FormularioModelosController(sugerencia: SugerenciasModelos.de(rubro))
          ..addListener(() {
            medida.conModelos = modelos.usa;
            notifyListeners();
          });
    extras = FormularioExtrasController(
      sugerencias: SugerenciasExtras.de(rubro),
    )..addListener(notifyListeners);
    combo = FormularioComboController(
      nombre: SugerenciasCombo.de(rubro),
      productos: productosParaCombo,
      idPropio: producto?.id ?? '',
    )..addListener(notifyListeners);
    _precargarDesde(producto);
    final guardado = producto;
    if (guardado != null) extras.precargar(guardado);
    if (guardado != null) combo.precargar(guardado);
    if (guardado != null && guardado.tieneModelos) {
      modelos.precargar(
        guardado,
        factorStock: LecturaUnidadesProducto.factorDe(guardado.medidaUnidad),
      );
      medida.conModelos = true;
    }
  }

  /// Producto editado (null si es nuevo).
  final Producto? producto;
  final List<String> categoriasDisponibles;

  /// Los productos cargados en el panel: de aquí se eligen las partes de un
  /// combo (y se calcula su stock).
  final List<Producto> productosParaCombo;

  /// Rubro del negocio: solo decide qué palabras se sugieren para nombrar
  /// lo que cambia (Color, Aroma, Sabor…).
  final String rubro;

  /// Catálogo de venta del negocio. Puede llegar después (reintento): el
  /// widget lo actualiza al reconstruirse, sin volver a precargar.
  CatalogoVentaPersistido? catalogoVenta;

  /// Estado del modo "Por medida".
  late final FormularioMedidaController medida;

  /// Estado de las variables: modelos con foto y sus filas con stock.
  late final FormularioModelosController modelos;

  /// Extras: lo que el cliente puede agregar. No aplican a «Lo peso».
  late final FormularioExtrasController extras;

  /// Combo: varios productos en uno, con precio propio y stock calculado.
  late final FormularioComboController combo;

  late final TextEditingController nombreCtrl;
  late final TextEditingController descripcionCtrl;

  /// Estado de «Lo cuento»: presentación, formato, precio y stock simples.
  late final FormularioPresentacionController presentacion;

  TextEditingController get stockPresentacionCtrl => presentacion.stockCtrl;
  TextEditingController get precioPresentacionCtrl => presentacion.precioCtrl;

  late bool esStockInfinito;
  late bool tieneDelivery;
  String categoria = '';

  ModoVenta? modoVista;
  String get presentacionId => presentacion.id;
  String get formatoEtiqueta => presentacion.formatoEtiqueta;

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
      _sugerirSegunModo();
      return;
    }

    if (producto.esPorMedida) {
      modoVista = ModoVenta.medida;
      medida.precargar(producto);
      return;
    }

    modoVista = ModoVenta.presentacion;
    presentacion.precargar(producto);

    // Etiqueta legacy tipo kg/g/L/ml: se SUGIERE el modo medida, sin
    // migrar nada (los campos de medida quedan vacíos a propósito).
    if (presentacionId.isEmpty &&
        LecturaUnidadesProducto.esUnidadDeMedida(producto.etiquetaUnidad)) {
      modoVista = ModoVenta.medida;
      medida.unidad = producto.etiquetaUnidad;
    }
  }

  /// Producto nuevo: deja elegida la primera presentación activa (el orden
  /// lo define el preset del rubro) o la única medida activa. No pisa lo
  /// que la persona ya eligió.
  void _sugerirSegunModo() {
    if (!esNuevo) return;
    if (modoVista == ModoVenta.presentacion && presentacionId.isEmpty) {
      final activas = presentacionesActivas;
      if (activas.isNotEmpty) presentacion.aplicar(activas.first.id);
    }
    if (modoVista == ModoVenta.medida) medida.sugerirFamilia();
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

  /// Todas las medidas del catálogo con familia, activas o no.
  List<MedidaVentaPersistida> get medidasDelCatalogo =>
      (catalogoVenta?.medidas ?? const <MedidaVentaPersistida>[])
          .where((medida) => medida.familia != null)
          .toList();

  /// Un producto ya guardado por medida sigue mostrando "Por medida" aunque
  /// el negocio haya desactivado esa medida (nada se cambia solo).
  List<ModoVenta> get modosDisponibles {
    final modos = <ModoVenta>[];
    if (presentacionesActivas.isNotEmpty) modos.add(ModoVenta.presentacion);
    if (medidasActivas.isNotEmpty || (producto?.esPorMedida ?? false)) {
      modos.add(ModoVenta.medida);
    }
    return modos;
  }

  List<String> get categoriasEfectivas {
    final categorias = <String>{...categoriasDisponibles};
    final categoriaGuardada = producto?.categoria ?? '';
    if (categoriaGuardada.trim().isNotEmpty) categorias.add(categoriaGuardada);
    return categorias.toList();
  }

  String get etiquetaLegacy => LecturaUnidadesProducto.etiquetaLegacy(producto);

  // ── Presentación ──────────────────────────────────────────────────────

  bool get presentacionCompleta => presentacion.completa;

  /// Los formatos de la presentación elegida (para elegir el tamaño de cada
  /// fila de un modelo). Vacío si no hay presentación.
  List<FormatoPresentacion> get formatosDePresentacion => presentacion.formatos;

  /// Nombre de la presentación elegida ("Jaba"); '' si no hay.
  String get nombrePresentacion => presentacion.nombre;

  /// "por unidad", "por botella (500 ml)"; '' sin presentación elegida.
  String get textoPrecioPresentacion => presentacion.textoPrecio;

  /// En qué se cuenta el stock: "unidades", "botellas"…
  String get unidadStockPresentacion => presentacion.unidadStock;

  // ── Validación ────────────────────────────────────────────────────────

  bool get medidaCompleta => medida.completa(stockInfinito: esStockInfinito);

  int? get precioVisibleCentavos {
    if (modoVista == ModoVenta.medida) return medida.precioCentavos;
    return textoACentavos(precioPresentacionCtrl.text);
  }

  bool get _stockPresentacionValido =>
      esStockInfinito || (int.tryParse(stockPresentacionCtrl.text) ?? -1) >= 0;

  bool get _porMedida => modoVista == ModoVenta.medida;
  int get _factorStock => LecturaUnidadesProducto.factorDe(medida.unidad);

  String? get _faltaModelos => modelos.queFalta(
    porMedida: _porMedida,
    stockInfinito: esStockInfinito,
    factorStock: _factorStock,
    unidadBase: medida.unidadBaseNombre,
  );

  /// Con variables: la medida o la presentación están elegidas y todos los
  /// modelos tienen sus filas con precio y stock.
  bool get _camposOkConModelos {
    if (_porMedida) {
      if (!medida.vistaValida(stockInfinito: esStockInfinito)) return false;
      if (!medidaCompleta) return false;
    } else if (presentacion.elegida == null) {
      return false;
    }
    return _faltaModelos == null;
  }

  /// La foto es obligatoria. Con variables la tiene cada modelo; un combo
  /// puede usar la imagen conjunta de las fotos de sus productos.
  bool get _fotoOk =>
      fotoNuevaBytes != null ||
      urlImagenActual.isNotEmpty ||
      (combo.usa && combo.fotosDeLasPartes.isNotEmpty);

  String? get _faltaFoto {
    if (modelos.usa || _fotoOk) return null;
    return combo.usa
        ? 'Falta: foto del ${combo.nombre.palabra}'
        : 'Falta: foto del producto';
  }

  /// Los extras no aplican a «Lo peso»: ahí no se piden ni se guardan.
  String? get _faltaExtras =>
      _porMedida && !combo.usa ? null : extras.queFalta();

  bool get camposOk {
    if (_guardando) return false;
    if (nombreCtrl.text.trim().isEmpty) return false;
    if (categoria.isEmpty) return false;
    if (_faltaFoto != null) return false;
    if (_faltaExtras != null) return false;
    if (combo.usa) return combo.queFalta() == null;
    if (modelos.usa) return _camposOkConModelos;

    if (modoVista == ModoVenta.medida) {
      if (!medida.vistaValida(stockInfinito: esStockInfinito)) return false;
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

  /// Lo primero que impide guardar, para decírselo a la persona ("Falta:
  /// precio", "Revisa: stock"). null si se puede guardar. Va en el mismo
  /// orden del formulario: nombre → categoría → presentación/formato o qué
  /// mides → precio → cantidad de «Otra cantidad» → stock → regla propia.
  String? get queFalta {
    if (camposOk || _guardando) return null;
    return _faltaCampos ?? _faltaExtras;
  }

  String? get _faltaCampos {
    final foto = _faltaFoto;
    if (foto != null) return foto;
    if (nombreCtrl.text.trim().isNotEmpty &&
        categoria.isNotEmpty &&
        combo.usa) {
      return combo.queFalta();
    }
    if (nombreCtrl.text.trim().isEmpty) return 'Falta: nombre del producto';
    if (categoria.isEmpty) return 'Falta: categoría';

    if (modelos.usa) {
      if (_porMedida) {
        final faltaMedida = medida.queFalta(
          stockInfinito: esStockInfinito,
          exigirTodo: true,
        );
        if (faltaMedida != null) return faltaMedida;
      } else if (presentacion.elegida == null) {
        return 'Falta: presentación';
      }
      return _faltaModelos;
    }

    if (modoVista == ModoVenta.medida) {
      return medida.queFalta(
        stockInfinito: esStockInfinito,
        exigirTodo: esNuevo,
      );
    }

    // Un producto antiguo puede guardarse sin presentación (regla 4).
    if (esNuevo) {
      if (presentacion.elegida == null) return 'Falta: presentación';
      if (!presentacionCompleta) return 'Falta: formato';
    }
    final centavos = precioVisibleCentavos;
    if (centavos == null || centavos <= 0) {
      return precioPresentacionCtrl.text.trim().isEmpty
          ? 'Falta: precio'
          : 'Revisa: precio';
    }
    if (!_stockPresentacionValido) {
      return stockPresentacionCtrl.text.trim().isEmpty
          ? 'Falta: stock'
          : 'Revisa: stock';
    }
    return null;
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
    _sugerirSegunModo();
    notifyListeners();
  }

  void cambiarPresentacion(String id) {
    presentacion.aplicar(id);
    notifyListeners();
  }

  void cambiarFormato(FormatoElegido elegido) {
    presentacion.elegirFormato(elegido);
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

  /// Las fotos nuevas de los modelos, por id de modelo, para subirlas.
  Map<String, FotoNueva> get fotosModelos => modelos.fotosNuevas;

  /// Arma el Producto con lo escrito (ConstructorProducto).
  Producto construirProducto() {
    final elegido = presentacion.formato;
    final reglaPropia = medida.reglaPropia;
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
        medidaFamilia: medida.familia,
        medidaUnidad: medida.unidad,
        referenciaBase: medida.referencia?.base,
        precioMedidaCentavos: medida.precioCentavos,
        stockMedidaBase: medida.stock?.base,
        minimoBase: reglaPropia ? medida.minimoPropio : null,
        incrementoBase: reglaPropia ? medida.incrementoPropio : null,
        presentacionCompleta: presentacionCompleta,
        presentacionId: presentacionId,
        presentacionNombre: nombrePresentacion,
        formatoValorBase: elegido?.valorBase ?? 0,
        formatoFamilia: elegido?.familia ?? '',
        formatoUnidad: elegido?.unidad ?? '',
        precioPresentacionCentavos: textoACentavos(precioPresentacionCtrl.text),
        stockPresentacion: int.tryParse(stockPresentacionCtrl.text) ?? 0,
        precioVisibleCentavos: precioVisibleCentavos,
        extras: _porMedida && !combo.usa ? const [] : extras.construir(),
        partes: combo.construir(),
        precioComboCentavos: combo.precioCentavos,
        sumaPartesCentavos: combo.sumaParaGuardar,
        tituloModelos: modelos.usa ? modelos.tituloCtrl.text.trim() : '',
        tituloFilas: modelos.usa ? modelos.tituloFilas : '',
        modelos: modelos.construir(
          porMedida: _porMedida,
          factorStock: _factorStock,
          unidadBase: medida.unidadBaseNombre,
        ),
      ),
    );
  }

  @override
  void dispose() {
    medida.dispose();
    modelos.dispose();
    extras.dispose();
    combo.dispose();
    nombreCtrl.dispose();
    descripcionCtrl.dispose();
    presentacion.dispose();
    super.dispose();
  }
}
