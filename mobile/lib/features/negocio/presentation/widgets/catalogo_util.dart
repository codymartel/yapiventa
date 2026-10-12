/// Utilidades de texto compartidas por el paso Catálogo.
///
/// Viven en un archivo aparte para que Categorías (paso_catalogo.dart) y
/// Presentaciones (editor_presentacion.dart) normalicen igual, sin duplicar
/// la lógica.
String colapsarEspacios(String texto) =>
    texto.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Normaliza para comparar duplicados ignorando mayúsculas, espacios y tildes.
String normalizarNombre(String texto) {
  const conTilde = 'áéíóúüñÁÉÍÓÚÜÑ';
  const sinTilde = 'aeiouunAEIOUUN';
  var normalizado = colapsarEspacios(texto).toLowerCase();
  for (var i = 0; i < conTilde.length; i++) {
    normalizado = normalizado.replaceAll(conTilde[i], sinTilde[i]);
  }
  return normalizado;
}