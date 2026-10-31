import 'package:flutter/widgets.dart';

import '../../../negocio/domain/models/catalogo_venta/formato_presentacion.dart';
import '../../../negocio/domain/models/catalogo_venta/opcion_presentacion.dart';
import '../../application/services/lectura_unidades_producto.dart';
import '../../domain/models/familia_unidad.dart';
import '../../domain/models/formato_elegido.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioPresentacionController
// ═════════════════════════════════════════════════════════════════════════
// Estado de la forma de venta «Lo cuento» del formulario de producto: la
// presentación elegida (Unidad, Botella, Jaba…), su formato, el precio y el
// stock simples. No notifica: quien lo usa (FormularioProductoController)
// avisa a la pantalla después de cada acción.
// ═════════════════════════════════════════════════════════════════════════
class FormularioPresentacionController {
  FormularioPresentacionController({
    required this.presentacionesActivas,
    required this.alCambiarPresentacion,
    String precio = '',
    String stock = '',
  }) : precioCtrl = TextEditingController(text: precio),
       stockCtrl = TextEditingController(text: stock);

  /// Las presentaciones activas del catálogo del negocio (pueden cambiar si
  /// el catálogo llega después).
  final List<OpcionPresentacion> Function() presentacionesActivas;

  /// Se llama al cambiar de presentación: los formatos guardados en las filas
  /// de los modelos ya no valen.
  final VoidCallback alCambiarPresentacion;

  final TextEditingController precioCtrl;
  final TextEditingController stockCtrl;

  String id = '';
  String formatoEtiqueta = '';
  FormatoElegido? formato;

  OpcionPresentacion? get elegida {
    for (final presentacion in presentacionesActivas()) {
      if (presentacion.id == id) return presentacion;
    }
    return null;
  }

  bool get completa {
    final presentacion = elegida;
    final elegido = formato;
    if (presentacion == null || elegido == null) return false;
    return presentacion.formatos.any(
      (candidato) =>
          candidato.valorBase == elegido.valorBase &&
          candidato.familia.name == elegido.familia &&
          candidato.unidadVisible.nombre == elegido.unidad,
    );
  }

  /// Los formatos de la presentación elegida (para elegir el tamaño de cada
  /// fila de un modelo). Vacío si no hay presentación.
  List<FormatoPresentacion> get formatos => elegida?.formatos ?? const [];

  /// Nombre de la presentación elegida ("Jaba"); '' si no hay.
  String get nombre => elegida?.nombre ?? '';

  /// "por unidad", "por botella (500 ml)"; '' sin presentación elegida.
  String get textoPrecio {
    final presentacion = elegida;
    if (presentacion == null) return '';
    final elegido = formato;
    return LecturaUnidadesProducto.textoPorPresentacion(
      nombre: presentacion.nombre,
      formatoEtiqueta: formatoEtiqueta,
      formatoEsUnaUnidad:
          elegido == null ||
          (elegido.familia == FamiliaUnidad.conteo.name &&
              elegido.valorBase == 1),
    );
  }

  /// En qué se cuenta el stock: "unidades", "botellas"…
  String get unidadStock {
    final presentacion = elegida;
    return presentacion == null
        ? ''
        : LecturaUnidadesProducto.plural(presentacion.nombre);
  }

  /// Muestra lo que el producto guardado tenía: nunca migra datos.
  void precargar(Producto producto) {
    id = producto.presentacionId;
    if (id.isEmpty || producto.formatoValorBase <= 0) return;
    final etiqueta = LecturaUnidadesProducto.etiquetaFormatoGuardado(
      producto,
      presentacionesActivas(),
    );
    formatoEtiqueta = etiqueta ?? '';
    formato = FormatoElegido(
      valorBase: producto.formatoValorBase,
      familia: producto.formatoFamilia?.name ?? '',
      unidad: producto.formatoUnidad,
    );
  }

  /// Elige una presentación. Con un solo formato lo deja elegido.
  void aplicar(String nuevoId) {
    id = nuevoId;
    alCambiarPresentacion();
    formato = null;
    formatoEtiqueta = '';
    final presentaciones = presentacionesActivas().where(
      (presentacion) => presentacion.id == nuevoId,
    );
    if (presentaciones.isEmpty) return;
    final formatos = presentaciones.first.formatos;
    if (formatos.length == 1) {
      formatoEtiqueta = formatos.first.etiqueta;
      formato = FormatoElegido(
        valorBase: formatos.first.valorBase,
        familia: formatos.first.familia.name,
        unidad: formatos.first.unidadVisible.nombre,
      );
    }
  }

  void elegirFormato(FormatoElegido elegido) {
    formato = elegido;
    formatoEtiqueta = LecturaUnidadesProducto.etiquetaDeFormato(
      valorBase: elegido.valorBase,
      familiaNombre: elegido.familia,
      unidadNombre: elegido.unidad,
    );
  }

  void dispose() {
    precioCtrl.dispose();
    stockCtrl.dispose();
  }
}
