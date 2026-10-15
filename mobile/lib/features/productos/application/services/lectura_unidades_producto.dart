import '../../../negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import '../../../negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import '../../../negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// LecturaUnidadesProducto
// ═════════════════════════════════════════════════════════════════════════
// Lectura de unidades del registro cerrado y de productos guardados (incluidos
// los legacy) para el formulario de producto. Funciones puras, sin Flutter.
// ═════════════════════════════════════════════════════════════════════════
class LecturaUnidadesProducto {
  LecturaUnidadesProducto._();

  /// Factor a unidad base de la unidad con ese nombre exacto; 0 si no existe.
  static int factorDe(String unidadNombre) {
    if (unidadNombre.isEmpty) return 0;
    return unidadRegistrada(unidadNombre)?.factorBase ?? 0;
  }

  /// Unidad del registro cerrado con ese nombre exacto (kg, L, unidad…).
  static UnidadRegistrada? unidadRegistrada(String nombre) {
    for (final familia in FamiliaUnidad.values) {
      for (final unidad in RegistroUnidades.unidadesDe(familia)) {
        if (unidad.nombre == nombre) return unidad;
      }
    }
    return null;
  }

  /// true si el nombre (sin distinguir mayúsculas) es una unidad de una
  /// familia de medida (no conteo): kg, L, m…
  static bool esUnidadDeMedida(String nombre) {
    if (nombre.isEmpty) return false;
    for (final familia in FamiliaUnidad.values) {
      if (familia == FamiliaUnidad.conteo) continue;
      for (final unidad in RegistroUnidades.unidadesDe(familia)) {
        if (unidad.nombre.toLowerCase() == nombre.toLowerCase()) return true;
      }
    }
    return false;
  }

  /// Etiqueta del formato guardado en el producto ("500 ml"). Primero la
  /// busca en las presentaciones activas; si ya no está, la reconstruye.
  static String? etiquetaFormatoGuardado(
    Producto producto,
    List<OpcionPresentacion> presentacionesActivas,
  ) {
    final familia = producto.formatoFamilia;
    if (familia == null || producto.formatoValorBase <= 0) return null;
    final guardada = presentacionesActivas
        .where((presentacion) => presentacion.id == producto.presentacionId)
        .expand((presentacion) => presentacion.formatos)
        .where(
          (formato) =>
              formato.valorBase == producto.formatoValorBase &&
              formato.familia == familia &&
              formato.unidadVisible.nombre == producto.formatoUnidad,
        )
        .toList();
    if (guardada.isNotEmpty) return guardada.first.etiqueta;
    try {
      final unidad = unidadRegistrada(producto.formatoUnidad);
      if (unidad == null) return null;
      return FormatoPresentacion(
        valorBase: producto.formatoValorBase,
        familia: familia,
        unidadVisible: unidad,
      ).etiqueta;
    } catch (_) {
      return null;
    }
  }

  /// Etiqueta de un formato elegido en el formulario; '' si no es válido.
  static String etiquetaDeFormato({
    required int valorBase,
    required String familiaNombre,
    required String unidadNombre,
  }) {
    final familia = FamiliaUnidad.values.firstWhere(
      (familia) => familia.name == familiaNombre,
      orElse: () => FamiliaUnidad.conteo,
    );
    final unidad = unidadRegistrada(unidadNombre);
    if (unidad == null) return '';
    try {
      return FormatoPresentacion(
        valorBase: valorBase,
        familia: familia,
        unidadVisible: unidad,
      ).etiqueta;
    } catch (_) {
      return '';
    }
  }

  /// Plural simple en español de un nombre de presentación, en minúsculas:
  /// unidad → unidades, botella → botellas, porción → porciones.
  static String plural(String nombre) {
    final texto = nombre.trim().toLowerCase();
    if (texto.isEmpty) return texto;
    const terminanEnS = {'set', 'sachet', 'spray'};
    if (terminanEnS.contains(texto)) return '${texto}s';
    if (texto.endsWith('ón')) {
      return '${texto.substring(0, texto.length - 2)}ones';
    }
    if (texto.endsWith('z')) {
      return '${texto.substring(0, texto.length - 1)}ces';
    }
    if ('aeiouáéó'.contains(texto[texto.length - 1])) return '${texto}s';
    return '${texto}es';
  }

  /// Texto que acompaña al precio de una presentación: "por unidad",
  /// "por botella (500 ml)". El formato se omite cuando es 1 unidad.
  static String textoPorPresentacion({
    required String nombre,
    required String formatoEtiqueta,
    required bool formatoEsUnaUnidad,
  }) {
    final base = 'por ${nombre.trim().toLowerCase()}';
    if (formatoEtiqueta.isEmpty || formatoEsUnaUnidad) return base;
    return '$base ($formatoEtiqueta)';
  }

  /// Unidad propia de un producto legacy (sin presentación); '' si no aplica.
  static String etiquetaLegacy(Producto? producto) {
    if (producto == null) return '';
    if (producto.presentacionId.isNotEmpty) return '';
    return producto.etiquetaUnidad;
  }
}
