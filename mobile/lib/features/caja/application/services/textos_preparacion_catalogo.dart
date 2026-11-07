import 'package:mobile/features/productos/domain/repositories/repositorio_relleno_catalogo.dart';

// ═════════════════════════════════════════════════════════════════════════
// TextosPreparacionCatalogo
// ═════════════════════════════════════════════════════════════════════════
// Los textos del resultado de preparar el catálogo (pantalla B10), con su
// singular y su plural. Funciones puras.
// ═════════════════════════════════════════════════════════════════════════
abstract final class TextosPreparacionCatalogo {
  /// «38 productos revisados», «1 producto revisado».
  static String revisados(int total) {
    if (total == 1) return '1 producto revisado';
    return '$total productos revisados';
  }

  /// «36 preparados · 2 ya estaban listos». Vacío si no hubo productos.
  static String detalle(ResultadoRelleno r) {
    if (r.total == 0) return 'Cuando agregues productos ya estarán listos.';
    final partes = <String>[];
    if (r.actualizados > 0) {
      partes.add(
        r.actualizados == 1 ? '1 preparado' : '${r.actualizados} preparados',
      );
    }
    if (r.yaCompletos > 0) {
      partes.add(
        r.yaCompletos == 1
            ? '1 ya estaba listo'
            : '${r.yaCompletos} ya estaban listos',
      );
    }
    if (r.omitidos > 0) {
      partes.add(
        r.omitidos == 1
            ? '1 no se pudo revisar'
            : '${r.omitidos} no se pudieron revisar',
      );
    }
    return partes.join(' · ');
  }
}
