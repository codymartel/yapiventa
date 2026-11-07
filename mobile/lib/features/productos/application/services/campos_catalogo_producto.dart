import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// CamposCatalogoProducto
// ═════════════════════════════════════════════════════════════════════════
// Los dos campos que se guardan junto al producto para que Caja lo busque y
// lo filtre sin leer todo el catálogo:
//
//   nombreBusqueda → el nombre en minúsculas, sin tildes y sin espacios de más
//                    («Piña  Dulce» → «pina dulce»). La búsqueda es por el
//                    INICIO del nombre.
//   tipoCaja       → simple, medida, variable o combo (filtro rápido).
//
// Funciones puras: se calculan al guardar el producto, nunca se escriben a
// mano. (`vendidos` no está aquí: lo suben las ventas, no el formulario.)
// ═════════════════════════════════════════════════════════════════════════
abstract final class CamposCatalogoProducto {
  static const String tipoSimple = 'simple';
  static const String tipoMedida = 'medida';
  static const String tipoVariable = 'variable';
  static const String tipoCombo = 'combo';

  /// Los tipos que puede traer `tipoCaja`.
  static const List<String> tipos = [
    tipoSimple,
    tipoMedida,
    tipoVariable,
    tipoCombo,
  ];

  /// Mínimo de letras para buscar por nombre (con menos se listan todos).
  static const int minimoLetras = 2;

  /// Largo máximo que se guarda (la búsqueda nunca necesita más).
  static const int maximoLetras = 60;

  static const String _conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  static const String _sinTilde = 'aaaaaeeeeiiiiooooouuuunc';

  /// Minúsculas, sin tildes (la ñ cuenta como n), espacios juntos y recortado.
  /// Para guardar el nombre y para normalizar lo que el cajero escribe.
  static String nombreBusqueda(String nombre) {
    final buffer = StringBuffer();
    var espacioPendiente = false;
    for (final rune in nombre.toLowerCase().runes) {
      var letra = String.fromCharCode(rune);
      final i = _conTilde.indexOf(letra);
      if (i >= 0) letra = _sinTilde[i];
      if (letra.trim().isEmpty) {
        espacioPendiente = buffer.isNotEmpty;
        continue;
      }
      if (espacioPendiente) buffer.write(' ');
      espacioPendiente = false;
      buffer.write(letra);
    }
    final texto = buffer.toString();
    return texto.length <= maximoLetras
        ? texto
        : texto.substring(0, maximoLetras);
  }

  /// combo > variable > medida > simple.
  static String tipoCaja(Producto producto) {
    if (producto.esCombo) return tipoCombo;
    if (producto.tieneModelos) return tipoVariable;
    if (producto.esPorMedida) return tipoMedida;
    return tipoSimple;
  }
}
