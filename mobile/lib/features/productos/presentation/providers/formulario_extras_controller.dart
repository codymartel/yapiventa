import 'package:flutter/widgets.dart';

import '../../application/services/entrada_numerica.dart';
import '../../application/services/sugerencias_extras.dart';
import '../../application/services/validador_modelos.dart';
import '../../domain/models/estructura_producto.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioExtrasController
// ═════════════════════════════════════════════════════════════════════════
// Estado de los EXTRAS del formulario de producto: «¿el cliente puede agregar
// algo extra?» (Sí/No) y sus filas de nombre y precio. Un extra no tiene
// stock. Lo usa FormularioProductoController.
//
// REGLAS:
//   - Máximo [ExtraProducto.maximo] extras; la fila totalmente vacía se
//     ignora al guardar.
//   - Precio vacío = gratis; si se escribe debe ser mayor que 0 (céntimos
//     enteros, nunca double).
//   - Con «No» los extras escritos NO se guardan, pero siguen aquí por si se
//     vuelve a tocar «Sí» antes de guardar el producto.
// ═════════════════════════════════════════════════════════════════════════

class ExtraEditable {
  ExtraEditable({required this.id, String nombre = '', String precio = ''})
    : nombreCtrl = TextEditingController(text: nombre),
      precioCtrl = TextEditingController(text: precio);

  final String id;
  final TextEditingController nombreCtrl;
  final TextEditingController precioCtrl;

  String get _nombre => nombreCtrl.text.trim();
  String get _precio => precioCtrl.text.trim();

  /// Fila sin nada escrito: no cuenta ni se guarda.
  bool get vacia => _nombre.isEmpty && _precio.isEmpty;

  void dispose() {
    nombreCtrl.dispose();
    precioCtrl.dispose();
  }
}

/// Foto de los extras escritos (ver [FormularioExtrasController.copiar]).
class ExtrasCopia {
  const ExtrasCopia(this.usa, this.filas);

  final bool usa;
  final List<({String id, String nombre, String precio})> filas;
}

class FormularioExtrasController extends ChangeNotifier {
  FormularioExtrasController({required this.sugerencias});

  /// Los extras de ejemplo del rubro (botones que se tocan).
  final List<ExtraSugerido> sugerencias;

  /// «¿El cliente puede agregar algo extra?»: Sí.
  bool usa = false;

  final List<ExtraEditable> filas = [];
  int _secuencia = 0;

  String _nuevoId() {
    final tiempo = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'e$tiempo${(_secuencia++).toRadixString(36)}';
  }

  bool get puedeAgregar => filas.length < ExtraProducto.maximo;

  /// Cuántos extras tiene de verdad (sin contar filas vacías); 0 con «No».
  int get cantidad => usa ? filas.where((fila) => !fila.vacia).length : 0;

  /// Los extras de ejemplo que todavía no se agregaron.
  List<ExtraSugerido> get sugerenciasPendientes => [
    for (final sugerido in sugerencias)
      if (!_yaEsta(sugerido.nombre)) sugerido,
  ];

  bool _yaEsta(String nombre) {
    final limpio = nombre.trim().toLowerCase();
    return filas.any((fila) => fila._nombre.toLowerCase() == limpio);
  }

  // ── Precarga ──────────────────────────────────────────────────────────

  /// Un producto guardado con extras arranca con «Sí» y sus filas.
  void precargar(Producto producto) {
    if (producto.extras.isEmpty) return;
    usa = true;
    for (final extra in producto.extras) {
      filas.add(
        ExtraEditable(
          id: extra.id,
          nombre: extra.nombre,
          precio: extra.precioCentavos > 0
              ? centavosATexto(extra.precioCentavos)
              : '',
        ),
      );
    }
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  void activar(bool valor) {
    usa = valor;
    notifyListeners();
  }

  void trasCambioTexto() => notifyListeners();

  /// Una fila en blanco para escribir un extra propio.
  void agregar() {
    if (!puedeAgregar) return;
    filas.add(ExtraEditable(id: _nuevoId()));
    notifyListeners();
  }

  /// Toca un extra de ejemplo: lo agrega con su precio.
  void agregarSugerido(ExtraSugerido sugerido) {
    if (!puedeAgregar || _yaEsta(sugerido.nombre)) return;
    filas.add(
      ExtraEditable(
        id: _nuevoId(),
        nombre: sugerido.nombre,
        precio: sugerido.precioCentavos > 0
            ? centavosATexto(sugerido.precioCentavos)
            : '',
      ),
    );
    notifyListeners();
  }

  void quitar(String id) {
    final indice = filas.indexWhere((fila) => fila.id == id);
    if (indice == -1) return;
    filas.removeAt(indice).dispose();
    notifyListeners();
  }

  // ── Copia para «Cancelar» ─────────────────────────────────────────────

  /// Lo escrito ahora, para que «Cancelar» del editor lo deje como estaba.
  ExtrasCopia copiar() => ExtrasCopia(usa, [
    for (final fila in filas)
      (id: fila.id, nombre: fila.nombreCtrl.text, precio: fila.precioCtrl.text),
  ]);

  void restaurar(ExtrasCopia copia) {
    usa = copia.usa;
    for (final fila in filas) {
      fila.dispose();
    }
    filas
      ..clear()
      ..addAll([
        for (final f in copia.filas)
          ExtraEditable(id: f.id, nombre: f.nombre, precio: f.precio),
      ]);
    notifyListeners();
  }

  // ── Validación y salida ───────────────────────────────────────────────

  /// Lo primero que impide guardar: «Falta: nombre del extra» o «Revisa: …».
  /// null si no usa extras o todo está bien.
  String? queFalta() {
    if (!usa) return null;
    for (final fila in filas) {
      if (fila.vacia) continue;
      if (fila._nombre.isEmpty) return 'Falta: nombre del extra';
      final precio = fila._precio;
      if (precio.isNotEmpty && (textoACentavos(precio) ?? 0) <= 0) {
        return 'Revisa: precio de ${fila._nombre}';
      }
    }
    final repetido = ValidadorModelos.primerRepetido(
      filas.where((fila) => !fila.vacia).map((fila) => fila.nombreCtrl.text),
    );
    if (repetido != null) return 'Revisa: «$repetido» está repetido';
    return null;
  }

  /// Los extras ya como dominio, en enteros. Vacío con «No».
  List<ExtraProducto> construir() {
    if (!usa) return const [];
    return [
      for (final fila in filas)
        if (!fila.vacia)
          ExtraProducto(
            id: fila.id,
            nombre: fila._nombre,
            precioCentavos: textoACentavos(fila._precio) ?? 0,
          ),
    ];
  }

  @override
  void dispose() {
    for (final fila in filas) {
      fila.dispose();
    }
    super.dispose();
  }
}
