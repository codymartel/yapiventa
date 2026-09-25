// ═════════════════════════════════════════════════════════════════════════
// CategoriaPersonalizada
// ═════════════════════════════════════════════════════════════════════════
// Una categoría creada por el usuario, distinta de las que trae el preset del
// rubro. `categorias` en Firestore es un `List<String>` sin origen, así que
// esta estructura existe para poder distinguir "esta categoría la puso el
// negocio" de "esta categoría venía del preset", que es lo que hoy no se puede
// saber y hace que un cambio de rubro borre datos del usuario.
//
// REGLAS:
//   - [clave] es la IDENTIDAD estable y SIEMPRE canónica (ver
//     [canonicalizarCategoria]). No depende de [nombre]: renombrar la
//     categoría no debe cambiar su identidad, porque los productos la
//     referencian por nombre y la clave es lo que permite detectarla.
//   - [nombre] es la etiqueta visible. Se compara con la clave para detectar
//     choques, nunca para identificar.
//   - [activa] permite ocultar la categoría sin borrarla. Desactivar NO es
//     eliminar: es la distinción que el modelo legacy no puede expresar.
//
// DESTINO: solo dominio. La persistencia y la proyección materializada de
// `categorias` llegan en etapas posteriores.
// ═════════════════════════════════════════════════════════════════════════

/// Categoría creada por el usuario, con identidad canónica.
class CategoriaPersonalizada {
  /// Identidad estable. Producida por [canonicalizarCategoria].
  final String clave;

  /// Etiqueta visible tal como la escribió el usuario.
  final String nombre;

  /// false = oculta pero conservada. No implica borrado.
  final bool activa;

  const CategoriaPersonalizada({
    required this.clave,
    required this.nombre,
    this.activa = true,
  });

  /// Construye la categoría derivando la clave del nombre.
  ///
  /// Es la vía recomendada: garantiza que [clave] y [nombre] no puedan
  /// desincronizarse en la creación.
  factory CategoriaPersonalizada.crear(
    String nombre, {
    bool activa = true,
  }) => CategoriaPersonalizada(
    clave: canonicalizarCategoria(nombre),
    nombre: nombre.trim(),
    activa: activa,
  );

  /// Copia con cambios. OJO: cambiar [nombre] no re-deriva [clave] a propósito;
  /// la identidad sobrevive al renombrado.
  CategoriaPersonalizada copyWith({
    String? clave,
    String? nombre,
    bool? activa,
  }) => CategoriaPersonalizada(
    clave: clave ?? this.clave,
    nombre: nombre ?? this.nombre,
    activa: activa ?? this.activa,
  );

  /// Devuelve una copia con la misma clave y el nuevo nombre visible.
  ///
  /// Es el renombrado correcto: la identidad no cambia, la etiqueta sí.
  CategoriaPersonalizada renombrar(String nombreNuevo) =>
      CategoriaPersonalizada(clave: clave, nombre: nombreNuevo.trim());

  /// true si el nombre en minúsculas estorba: la clave no puede estar vacía
  /// porque no habría forma de identificar la categoría.
  String? validar() {
    if (nombre.trim().isEmpty) {
      return 'El nombre de la categoría no puede estar vacío.';
    }
    if (clave.isEmpty) {
      return 'La clave de la categoría no puede estar vacía.';
    }
    if (clave != canonicalizarCategoria(clave)) {
      return 'La clave "$clave" no es canónica.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoriaPersonalizada &&
          other.clave == clave &&
          other.nombre == nombre &&
          other.activa == activa;

  @override
  int get hashCode => Object.hash(clave, nombre, activa);

  @override
  String toString() =>
      'CategoriaPersonalizada(clave: $clave, nombre: $nombre, activa: $activa)';
}

/// Normaliza un nombre de categoría a su clave canónica.
///
/// ÚNICA fuente de verdad de la identidad de una categoría. La regla es
/// deliberadamente conservadora:
///
///   1. pasa a minúsculas;
///   2. quita tildes y diéresis (la "ñ" vale "n");
///   3. colapsa espacios/tabs/saltos de línea a un solo espacio;
///   4. recorta.
///
/// NO quita signos de puntuación. Quitar "Bebidas & Snacks" y "Bebidas y
/// Snacks" a la misma clave fundiría dos nombres distintos; el costo de no
/// hacerlo es que variantes cosméticas ("Bebidas-Snacks" vs "Bebidas Snacks")
/// tengan claves distintas, lo cual es una molestia pero nunca pérdida de
/// datos.
String canonicalizarCategoria(String nombre) {
  const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sinTilde = 'aaaaaeeeeiiiiooooouuuunc';
  var texto = nombre.toLowerCase();
  for (var i = 0; i < conTilde.length; i++) {
    texto = texto.replaceAll(conTilde[i], sinTilde[i]);
  }
  return texto.replaceAll(RegExp(r'\s+'), ' ').trim();
}
