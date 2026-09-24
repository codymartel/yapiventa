import 'package:mobile/features/productos/domain/models/familia_unidad.dart';

import 'formato_presentacion.dart';

// ═════════════════════════════════════════════════════════════════════════
// OpcionPresentacion
// ═════════════════════════════════════════════════════════════════════════
// Una forma de presentar un producto al cliente (ej. "Botella",
// "Frasco", "Caja"). Para ModoVenta.presentacion.
//
// REGLAS:
//   - [id] es ESTABLE: no debe depender del nombre, porque el nombre puede
//     cambiar sin que cambie la identidad de la opción.
//   - [formatos] son los tamaños físicos disponibles (ej. 625 ml, 1 L).
//   - NO se admiten formatos duplicados normalizados: dos formatos que
//     representan la misma cantidad en base (1000 ml y 1 L) son el mismo
//     formato, porque se normalizan a familia + valorBase.
//   - [obligatoria] y [personalizada] son flags de comportamiento ajeno al
//     catálogo base; [activa] permite deshabilitar la opción sin borrarla.
// ═════════════════════════════════════════════════════════════════════════
class OpcionPresentacion {
  final String id;
  final String nombre;
  final List<FormatoPresentacion> formatos;
  final bool activa;
  final bool obligatoria;
  final bool personalizada;

  OpcionPresentacion({
    required this.id,
    required this.nombre,
    required List<FormatoPresentacion> formatos,
    this.activa = true,
    this.obligatoria = false,
    this.personalizada = false,
  }) : formatos = List.unmodifiable(formatos);

  /// Valida el conjunto: id estable, formatos sin duplicados normalizados.
  String? validar() {
    if (id.trim().isEmpty) {
      return 'El id no puede estar vacío.';
    }
    if (nombre.trim().isEmpty) {
      return 'El nombre no puede estar vacío.';
    }
    if (formatos.isEmpty) {
      return 'Debe haber al menos un formato de presentación.';
    }

    final vistos = <(FamiliaUnidad, int)>{};
    for (final formato in formatos) {
      final clave = (formato.familia, formato.valorBase);
      if (!vistos.add(clave)) {
        return 'Formato duplicado: ${formato.etiqueta} es la misma cantidad '
            'que un formato ya incluido.';
      }
    }
    return null;
  }
}
