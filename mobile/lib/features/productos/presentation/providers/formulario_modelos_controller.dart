import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/services/entrada_numerica.dart';
import '../../application/services/sugerencias_modelos.dart';
import '../../application/services/validador_modelos.dart';
import '../../domain/models/estructura_producto.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/foto_nueva.dart';
import '../../domain/models/formato_elegido.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioModelosController
// ═════════════════════════════════════════════════════════════════════════
// Estado de las VARIABLES del formulario de producto: "¿viene en distintos
// colores, aromas, sabores…?", la palabra que el vendedor le pone, sus
// modelos (con foto) y las filas "Se vende en" de cada uno, donde vive el
// stock. Lo usa FormularioProductoController.
//
// REGLAS:
//   - La foto de cada modelo es obligatoria (sin foto principal aparte).
//   - El modelo NO tiene stock propio: su total se calcula con candado.
//   - Por presentación cada modelo tiene sus filas (talla, formato…). Por
//     medida cada modelo tiene UNA fila: su precio y su stock.
//   - Un modelo nuevo copia las filas del primero con el stock vacío.
//   - Dinero y stock se leen como enteros (céntimos, unidades, unidad base).
// ═════════════════════════════════════════════════════════════════════════

class FilaEditable {
  FilaEditable({
    required this.id,
    String etiqueta = '',
    String precio = '',
    String stock = '',
    this.formato,
  }) : etiquetaCtrl = TextEditingController(text: etiqueta),
       precioCtrl = TextEditingController(text: precio),
       stockCtrl = TextEditingController(text: stock);

  final String id;
  final TextEditingController etiquetaCtrl;
  final TextEditingController precioCtrl;
  final TextEditingController stockCtrl;

  /// Tamaño real cuando la presentación tiene formatos (botella de 500 ml).
  FormatoElegido? formato;

  void dispose() {
    etiquetaCtrl.dispose();
    precioCtrl.dispose();
    stockCtrl.dispose();
  }
}

class ModeloEditable {
  ModeloEditable({
    required this.id,
    String nombre = '',
    this.urlImagen = '',
    this.cloudinaryPublicId,
  }) : nombreCtrl = TextEditingController(text: nombre);

  final String id;
  final TextEditingController nombreCtrl;
  final List<FilaEditable> filas = [];
  String urlImagen;
  final String? cloudinaryPublicId;
  Uint8List? fotoNuevaBytes;
  String? fotoNuevaNombre;

  /// Con variables la foto de cada modelo es obligatoria: no hay foto
  /// principal, la portada sale de la del primero.
  bool get tieneFoto => fotoNuevaBytes != null || urlImagen.isNotEmpty;

  void dispose() {
    nombreCtrl.dispose();
    for (final fila in filas) {
      fila.dispose();
    }
  }
}

class FormularioModelosController extends ChangeNotifier {
  FormularioModelosController({required this.sugerencia})
    : tituloFilas = sugerencia.tituloFilas;

  final SugerenciaModelos sugerencia;

  /// "¿Viene en distintos …?": Sí.
  bool usa = false;

  /// La palabra del vendedor para lo que cambia ("Color", "Aroma").
  final TextEditingController tituloCtrl = TextEditingController();

  /// La palabra para las filas ("Talla", "Formato").
  String tituloFilas;

  final List<ModeloEditable> modelos = [];
  int _secuencia = 0;

  String _nuevoId(String prefijo) {
    final tiempo = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$prefijo$tiempo${(_secuencia++).toRadixString(36)}';
  }

  String get _palabra => tituloCtrl.text.trim().toLowerCase();

  bool get puedeAgregarModelo => modelos.length < ValidadorModelos.maxModelos;

  bool puedeAgregarFila(ModeloEditable modelo) =>
      modelo.filas.length < ValidadorModelos.maxFilas;

  // ── Precarga ──────────────────────────────────────────────────────────

  /// Precarga desde un producto guardado con modelos. [factorStock] es el
  /// factor de la unidad del producto por medida (1000 para kg).
  void precargar(Producto producto, {required int factorStock}) {
    if (!producto.tieneModelos) return;
    usa = true;
    tituloCtrl.text = producto.tituloModelos;
    if (producto.tituloFilas.isNotEmpty) tituloFilas = producto.tituloFilas;
    for (final guardado in producto.modelos) {
      final modelo = ModeloEditable(
        id: guardado.id,
        nombre: guardado.nombre,
        urlImagen: guardado.urlImagen,
        cloudinaryPublicId: guardado.cloudinaryPublicId,
      );
      for (final fila in guardado.filas) {
        final stockBase = fila.stockBase;
        modelo.filas.add(
          FilaEditable(
            id: fila.id,
            etiqueta: fila.etiqueta,
            precio: fila.precioCentavos > 0
                ? centavosATexto(fila.precioCentavos)
                : '',
            stock: producto.esPorMedida
                ? (stockBase == null
                      ? ''
                      : baseATextoVisual(stockBase, factorStock))
                : '${fila.stock}',
            formato: fila.formatoValorBase > 0 && fila.formatoFamilia != null
                ? FormatoElegido(
                    valorBase: fila.formatoValorBase,
                    familia: fila.formatoFamilia!.name,
                    unidad: fila.formatoUnidad,
                  )
                : null,
          ),
        );
      }
      modelos.add(modelo);
    }
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  void activar(bool valor, {required bool porMedida}) {
    usa = valor;
    if (valor && modelos.isEmpty) _agregar(porMedida: porMedida);
    notifyListeners();
  }

  void usarPalabra(String palabra) {
    tituloCtrl.text = palabra;
    notifyListeners();
  }

  void cambiarTituloFilas(String palabra) {
    tituloFilas = palabra;
    notifyListeners();
  }

  void trasCambioTexto() => notifyListeners();

  void agregarModelo({required bool porMedida}) {
    if (!puedeAgregarModelo) return;
    _agregar(porMedida: porMedida);
    notifyListeners();
  }

  /// Un modelo nuevo parte de las filas del primero (mismas etiquetas y
  /// precios) con el stock vacío: solo falta escribir cuánto hay.
  void _agregar({required bool porMedida}) {
    final nuevo = ModeloEditable(id: _nuevoId('m'));
    final base = modelos.isEmpty ? null : modelos.first;
    if (base == null || base.filas.isEmpty) {
      nuevo.filas.add(FilaEditable(id: _nuevoId('f')));
    } else {
      final filas = porMedida ? base.filas.take(1) : base.filas;
      for (final fila in filas) {
        nuevo.filas.add(
          FilaEditable(
            id: _nuevoId('f'),
            etiqueta: fila.etiquetaCtrl.text,
            precio: fila.precioCtrl.text,
            formato: fila.formato,
          ),
        );
      }
    }
    modelos.add(nuevo);
  }

  void quitarModelo(String modeloId) {
    final indice = modelos.indexWhere((modelo) => modelo.id == modeloId);
    if (indice == -1) return;
    modelos.removeAt(indice).dispose();
    notifyListeners();
  }

  void agregarFila(String modeloId) {
    final modelo = _modelo(modeloId);
    if (modelo == null || !puedeAgregarFila(modelo)) return;
    final precio = modelo.filas.isEmpty
        ? ''
        : modelo.filas.first.precioCtrl.text;
    modelo.filas.add(FilaEditable(id: _nuevoId('f'), precio: precio));
    notifyListeners();
  }

  void quitarFila(String modeloId, String filaId) {
    final modelo = _modelo(modeloId);
    if (modelo == null) return;
    final indice = modelo.filas.indexWhere((fila) => fila.id == filaId);
    if (indice == -1) return;
    modelo.filas.removeAt(indice).dispose();
    notifyListeners();
  }

  /// Pone a todas las filas del modelo el precio de la primera.
  void mismoPrecio(String modeloId) {
    final modelo = _modelo(modeloId);
    if (modelo == null || modelo.filas.isEmpty) return;
    final precio = modelo.filas.first.precioCtrl.text;
    for (final fila in modelo.filas) {
      fila.precioCtrl.text = precio;
    }
    notifyListeners();
  }

  void elegirFormato(
    FilaEditable fila,
    String etiqueta,
    FormatoElegido? formato,
  ) {
    fila.etiquetaCtrl.text = etiqueta;
    fila.formato = formato;
    notifyListeners();
  }

  /// La presentación cambió: los formatos guardados en las filas ya no valen.
  void limpiarFormatos() {
    for (final modelo in modelos) {
      for (final fila in modelo.filas) {
        fila.formato = null;
      }
    }
  }

  void elegirFoto(String modeloId, XFile archivo, Uint8List bytes) {
    final modelo = _modelo(modeloId);
    if (modelo == null) return;
    modelo.fotoNuevaBytes = bytes;
    modelo.fotoNuevaNombre = archivo.name;
    notifyListeners();
  }

  ModeloEditable? _modelo(String id) {
    for (final modelo in modelos) {
      if (modelo.id == id) return modelo;
    }
    return null;
  }

  // ── Totales y avisos ──────────────────────────────────────────────────

  /// Suma del stock de las filas de un modelo (con candado en la pantalla).
  /// En medida es el stock en la unidad del producto, con decimales.
  String totalDelModelo(
    ModeloEditable modelo, {
    required bool porMedida,
    required int factorStock,
    required String unidadBase,
  }) {
    if (!porMedida) {
      var suma = 0;
      for (final fila in modelo.filas) {
        suma += int.tryParse(fila.stockCtrl.text.trim()) ?? 0;
      }
      return '$suma';
    }
    var base = 0;
    for (final fila in modelo.filas) {
      base += _stockBase(fila, factorStock, unidadBase) ?? 0;
    }
    return baseATextoVisual(base, factorStock);
  }

  /// "Ya tienes «Azul · M» dos veces"; '' si no hay repetidos en el modelo.
  String avisoRepetido(ModeloEditable modelo) {
    final repetida = ValidadorModelos.primerRepetido(
      modelo.filas.map((fila) => fila.etiquetaCtrl.text),
    );
    if (repetida == null) return '';
    final nombre = modelo.nombreCtrl.text.trim();
    final completa = nombre.isEmpty ? repetida : '$nombre · $repetida';
    return 'Ya tienes «$completa» dos veces: junta el stock o cambia el nombre.';
  }

  int? _stockBase(FilaEditable fila, int factor, String unidadBase) {
    final texto = fila.stockCtrl.text.trim();
    if (texto.isEmpty || factor <= 0) return null;
    return textoAUnidadBase(texto, factor, unidadBase: unidadBase).base;
  }

  /// Lo primero que impide guardar: "Falta: stock de Azul · M" o "Revisa: …".
  /// null si no usa modelos o todo está completo.
  String? queFalta({
    required bool porMedida,
    required bool stockInfinito,
    required int factorStock,
    required String unidadBase,
  }) {
    if (!usa) return null;
    final palabra = _palabra;
    if (palabra.isEmpty) return 'Falta: cómo se llama lo que cambia';
    if (modelos.isEmpty) return 'Falta: al menos un $palabra';

    final fila = tituloFilas.toLowerCase();
    for (final modelo in modelos) {
      final nombre = modelo.nombreCtrl.text.trim();
      if (nombre.isEmpty) return 'Falta: nombre del $palabra';
      if (!modelo.tieneFoto) return 'Falta: foto de $nombre';
      if (modelo.filas.isEmpty) return 'Falta: $fila de $nombre';
      for (final f in modelo.filas) {
        final etiqueta = f.etiquetaCtrl.text.trim();
        final cual = porMedida ? nombre : '$nombre · $etiqueta';
        if (!porMedida && etiqueta.isEmpty) {
          return 'Falta: nombre de $fila de $nombre';
        }
        final precio = f.precioCtrl.text.trim();
        if (precio.isEmpty) return 'Falta: precio de $cual';
        if ((textoACentavos(precio) ?? 0) <= 0) {
          return 'Revisa: precio de $cual';
        }
        if (stockInfinito) continue;
        final stock = f.stockCtrl.text.trim();
        if (stock.isEmpty) return 'Falta: stock de $cual';
        final valido = porMedida
            ? _stockBase(f, factorStock, unidadBase) != null
            : int.tryParse(stock) != null;
        if (!valido) return 'Revisa: stock de $cual';
      }
    }

    final nombreRepetido = ValidadorModelos.primerRepetido(
      modelos.map((modelo) => modelo.nombreCtrl.text),
    );
    if (nombreRepetido != null) {
      return 'Revisa: «$nombreRepetido» está repetido';
    }
    for (final modelo in modelos) {
      if (avisoRepetido(modelo).isNotEmpty) {
        final repetida = ValidadorModelos.primerRepetido(
          modelo.filas.map((f) => f.etiquetaCtrl.text),
        );
        return 'Revisa: «${modelo.nombreCtrl.text.trim()} · $repetida» está repetido';
      }
    }
    return null;
  }

  // ── Salida ────────────────────────────────────────────────────────────

  /// Las fotos nuevas por modelo, para subirlas al guardar.
  Map<String, FotoNueva> get fotosNuevas => {
    for (final modelo in modelos)
      if (modelo.fotoNuevaBytes != null)
        modelo.id: FotoNueva(
          bytes: modelo.fotoNuevaBytes!,
          nombreArchivo: modelo.fotoNuevaNombre ?? 'modelo.jpg',
        ),
  };

  /// Los modelos ya como dominio, con todo en enteros. Vacío si no usa
  /// modelos.
  List<ModeloProducto> construir({
    required bool porMedida,
    required int factorStock,
    required String unidadBase,
  }) {
    if (!usa) return const [];
    return [
      for (final modelo in modelos)
        ModeloProducto(
          id: modelo.id,
          nombre: modelo.nombreCtrl.text.trim(),
          urlImagen: modelo.urlImagen,
          cloudinaryPublicId: modelo.cloudinaryPublicId,
          filas: [
            for (final fila in modelo.filas)
              FilaVenta(
                id: fila.id,
                etiqueta: porMedida ? '' : fila.etiquetaCtrl.text.trim(),
                precioCentavos: textoACentavos(fila.precioCtrl.text) ?? 0,
                stock: porMedida
                    ? 0
                    : (int.tryParse(fila.stockCtrl.text.trim()) ?? 0),
                stockBase: porMedida
                    ? _stockBase(fila, factorStock, unidadBase)
                    : null,
                formatoValorBase: fila.formato?.valorBase ?? 0,
                formatoFamilia: _familia(fila.formato?.familia),
                formatoUnidad: fila.formato?.unidad ?? '',
              ),
          ],
        ),
    ];
  }

  FamiliaUnidad? _familia(String? nombre) {
    if (nombre == null) return null;
    for (final familia in FamiliaUnidad.values) {
      if (familia.name == nombre) return familia;
    }
    return null;
  }

  @override
  void dispose() {
    tituloCtrl.dispose();
    for (final modelo in modelos) {
      modelo.dispose();
    }
    super.dispose();
  }
}
