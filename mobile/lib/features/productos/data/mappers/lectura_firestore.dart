import '../../domain/models/familia_unidad.dart';
import '../../domain/models/modo_venta.dart';

// ═════════════════════════════════════════════════════════════════════════
// LecturaFirestore
// ═════════════════════════════════════════════════════════════════════════
// Lecturas DEFENSIVAS de campos de un documento de Firestore: un campo
// ausente, de otro tipo o inválido nunca rompe la lectura de un producto.
// Puro, sin Firestore.
// ═════════════════════════════════════════════════════════════════════════
abstract final class LecturaFirestore {
  static ModoVenta modoDesde(Object? valor) {
    if (valor is String && valor == ModoVenta.medida.name) {
      return ModoVenta.medida;
    }
    return ModoVenta.presentacion;
  }

  static FamiliaUnidad? familiaDesde(Object? valor) {
    if (valor is! String) return null;
    for (final familia in FamiliaUnidad.values) {
      if (familia.name == valor) return familia;
    }
    return null;
  }

  static int entero(Object? valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return 0;
  }

  /// Entero > 0 o null (campo opcional ausente, vacío o inválido).
  static int? enteroPositivoOpcional(Object? valor) =>
      valor is int && valor > 0 ? valor : null;

  static String texto(Object? valor) {
    final texto = valor;
    return texto is String ? texto.trim() : '';
  }
}
