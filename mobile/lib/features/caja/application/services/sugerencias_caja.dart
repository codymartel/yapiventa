import 'package:mobile/features/productos/application/services/campos_catalogo_producto.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// SugerenciasCaja
// ═════════════════════════════════════════════════════════════════════════
// Mientras el cajero escribe, se sugieren productos de lo YA
// CARGADO en memoria (cero lecturas). Coinciden si el texto empieza el nombre
// o una de sus palabras, sin importar mayúsculas ni tildes.
// ═════════════════════════════════════════════════════════════════════════
abstract final class SugerenciasCaja {
  static const int maximo = 5;

  static List<Producto> de(List<Producto> cargados, String texto) {
    final buscado = CamposCatalogoProducto.nombreBusqueda(texto);
    if (buscado.length < CamposCatalogoProducto.minimoLetras) return const [];
    final resultado = <Producto>[];
    for (final p in cargados) {
      final nombre = CamposCatalogoProducto.nombreBusqueda(p.nombre);
      final coincide =
          nombre.startsWith(buscado) || nombre.contains(' $buscado');
      if (coincide) resultado.add(p);
      if (resultado.length == maximo) break;
    }
    return resultado;
  }
}
