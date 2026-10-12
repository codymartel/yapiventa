import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../productos/domain/models/familia_unidad.dart';
import '../../domain/models/catalogo_venta/catalogo_venta_global.dart';
import '../../domain/models/catalogo_venta/formato_presentacion.dart';
import '../../domain/models/catalogo_venta/unidad_registrada.dart';
import '../providers/configuracion_negocio_provider.dart';
import 'catalogo_util.dart';

Future<void> abrirEditorPresentacion(BuildContext context, String? presentacionId) {
  final p = context.read<ConfiguracionNegocioProvider>();
  p.limpiarErrorCatalogo();
  return showDialog<void>(
    context: context,
    // El wizard vive DEBAJO del Navigator y `showDialog` cuelga la ruta en el
    // Navigator raíz, así que el editor no alcanza el provider por su context
    // (`ProviderNotFoundError`). Se reexpone la MISMA instancia dentro del
    // diálogo: `value:` no crea estado nuevo ni lo destruye al cerrar.
    builder: (_) => ChangeNotifierProvider.value(
      value: p,
      child: EditorPresentacion(presentacionId: presentacionId),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// Editor de presentación
// ═════════════════════════════════════════════════════════════════════════

class EditorPresentacion extends StatefulWidget {
  /// null → nueva presentación personalizada.
  final String? presentacionId;

  const EditorPresentacion({super.key, this.presentacionId});

  @override
  State<EditorPresentacion> createState() => _EditorPresentacionState();
}

class _EditorPresentacionState extends State<EditorPresentacion> {
  late final bool _esNueva = widget.presentacionId == null;
  late final String _id;
  late final String _nombre;
  late final bool _obligatoria;
  late final bool _personalizada;
  late List<FormatoPresentacion> _formatos;
  late bool _activa;
  late final bool _nombreEditable;

  late final TextEditingController _nombreController;
  final TextEditingController _valorController = TextEditingController();
  String? _error;

  late List<FamiliaUnidad> _familiasPermitidas;
  late FamiliaUnidad _familiaNueva;
  late UnidadRegistrada _unidadNueva;

  @override
  void initState() {
    super.initState();
    final p = context.read<ConfiguracionNegocioProvider>();
    if (_esNueva) {
      _id = '';
      _nombre = '';
      _obligatoria = false;
      _personalizada = true;
      _formatos = [];
      _activa = true;
      _nombreEditable = true;
    } else {
      final actual = p.presentacionPorId(widget.presentacionId!)!;
      _id = actual.id;
      _nombre = actual.nombre;
      _obligatoria = actual.obligatoria;
      _personalizada = actual.personalizada;
      _formatos = List.of(actual.formatos);
      _activa = actual.activa;
      _nombreEditable = actual.personalizada;
    }
    _nombreController = TextEditingController(text: _nombre);

    final familiasExistentes = _formatos.map((f) => f.familia).toSet();
    if (_personalizada) {
      _familiasPermitidas = {
        ...familiasExistentes,
        ...FamiliaUnidad.values,
      }.toList();
    } else {
      final delGlobal = CatalogoVentaGlobal.formatosDe(
        _id,
      ).map((formato) => formato.familia).toSet();
      _familiasPermitidas = [...familiasExistentes, ...delGlobal].toList();
    }
    _familiaNueva = _familiasPermitidas.isNotEmpty
        ? _familiasPermitidas.first
        : FamiliaUnidad.conteo;
    _unidadNueva = RegistroUnidades.baseDe(_familiaNueva);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  List<UnidadRegistrada> get _unidadesDeFamilia =>
      RegistroUnidades.unidadesDe(_familiaNueva);

  void _agregarFormato() {
    final valor = int.tryParse(_valorController.text.trim());
    final unidad = _unidadNueva;
    final familia = _familiaNueva;
    if (!RegistroUnidades.esDeFamilia(unidad, familia)) {
      setState(() => _error = 'La unidad no es válida para esta presentación.');
      return;
    }
    if (valor == null) {
      setState(
        () => _error = 'Escribe el valor del formato como número entero.',
      );
      return;
    }
    if (valor <= 0) {
      setState(() => _error = 'El valor debe ser un entero positivo.');
      return;
    }
    final valorBase = valor * unidad.factorBase;
    final formato = FormatoPresentacion(
      valorBase: valorBase,
      familia: familia,
      unidadVisible: unidad,
    );
    if (_formatos.any((existente) => existente.esMismoFormato(formato))) {
      setState(
        () => _error = '${formato.etiqueta} ya es un formato de $_nombre.',
      );
      return;
    }
    if (!_personalizada &&
        !CatalogoVentaGlobal.esFormatoPermitido(_id, formato)) {
      setState(
        () => _error =
            'El formato ${formato.etiqueta} no está permitido para '
            '$_nombre.',
      );
      return;
    }
    setState(() {
      _formatos = [..._formatos, formato];
      _error = null;
      _valorController.clear();
    });
  }

  String? _validarParaGuardar() {
    if (_nombreEditable) {
      final titulo = colapsarEspacios(_nombreController.text);
      if (titulo.isEmpty) {
        return 'El nombre de la presentación no puede estar vacío.';
      }
      final normalizado = normalizarNombre(titulo);
      final p = context.read<ConfiguracionNegocioProvider>();
      final duplicado = p.presentaciones.any(
        (presentacion) =>
            presentacion.id != _id &&
            normalizarNombre(presentacion.nombre) == normalizado,
      );
      if (duplicado) return 'Ya existe una presentación con ese nombre.';
    }
    if (_formatos.isEmpty) {
      return 'La presentación debe tener al menos un formato.';
    }
    final vistos = <(FamiliaUnidad, int)>{};
    for (final formato in _formatos) {
      if (formato.valorBase <= 0) {
        return 'El valor debe ser un entero positivo.';
      }
      if (!RegistroUnidades.esDeFamilia(
        formato.unidadVisible,
        formato.familia,
      )) {
        return 'La unidad no es válida para esta presentación.';
      }
      if (!vistos.add((formato.familia, formato.valorBase))) {
        return 'Formato duplicado: ${formato.etiqueta} es la misma cantidad '
            'que un formato ya incluido.';
      }
      if (!_personalizada &&
          !CatalogoVentaGlobal.esFormatoPermitido(_id, formato)) {
        return 'El formato ${formato.etiqueta} no está permitido para $_nombre.';
      }
    }
    return null;
  }

  void _guardar() {
    final p = context.read<ConfiguracionNegocioProvider>();
    final error = _validarParaGuardar();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    void cancelarPorError() {
      final mensaje = p.errorCatalogo;
      if (mensaje != null) {
        setState(() => _error = mensaje);
      }
    }

    if (_esNueva) {
      final titulo = colapsarEspacios(_nombreController.text);
      p.agregarPresentacionPersonalizada(nombre: titulo, formatos: _formatos);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
      Navigator.pop(context);
      return;
    }

    final actual = p.presentacionPorId(_id)!;
    final titulo = colapsarEspacios(_nombreController.text);
    if (_personalizada && titulo != actual.nombre) {
      p.renombrarPresentacion(_id, titulo);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    if (_activa != actual.activa) {
      p.establecerPresentacionActiva(_id, activa: _activa);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    final estadoActual = p.presentacionPorId(_id)!;
    for (final formato in _formatos) {
      if (estadoActual.formatos.any((f) => f.esMismoFormato(formato))) {
        continue;
      }
      p.agregarFormato(_id, formato);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    for (final formato in estadoActual.formatos) {
      if (_formatos.any((f) => f.esMismoFormato(formato))) {
        continue;
      }
      p.eliminarFormato(_id, formato);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    Navigator.pop(context);
  }

  void _eliminarFormato(int index) {
    if (_formatos.length <= 1) {
      setState(() => _error = 'No puedes quitar el único formato de $_nombre.');
      return;
    }
    setState(() {
      _formatos = [..._formatos]..removeAt(index);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tituloEditor = _esNueva
        ? 'Nueva presentación'
        : _personalizada
        ? 'Editar presentación personalizada'
        : 'Editar $_nombre';
    final tituloSwitch = _obligatoria
        ? 'Obligatoria (siempre activa)'
        : _activa
        ? 'Activa'
        : 'Inactiva';

    return AlertDialog(
      key: const Key('editor-presentacion'),
      backgroundColor: AppColors.superficie,
      title: Text(tituloEditor, style: const TextStyle(color: AppColors.texto)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('campo-nombre-presentacion'),
                controller: _nombreController,
                enabled: _nombreEditable,
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  suffixText: _nombreEditable ? null : 'Nombre del catálogo',
                  helperText: _nombreEditable
                      ? null
                      : 'Los nombres del catálogo son fijos.',
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Formatos',
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < _formatos.length; i++)
                _FilaFormatoExistente(
                  formato: _formatos[i],
                  puedeEliminar: _formatos.length > 1,
                  onEliminar: () => _eliminarFormato(i),
                ),
              const SizedBox(height: 8),
              if (_personalizada)
                DropdownButtonFormField<FamiliaUnidad>(
                  key: const Key('campo-familia-formato'),
                  initialValue: _familiaNueva,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final familia in _familiasPermitidas)
                      DropdownMenuItem(
                        value: familia,
                        child: Text(_etiquetaFamilia(familia)),
                      ),
                  ],
                  onChanged: (familia) {
                    if (familia == null) return;
                    setState(() {
                      _familiaNueva = familia;
                      _unidadNueva = RegistroUnidades.baseDe(familia);
                      _error = null;
                    });
                  },
                ),
              if (_personalizada) const SizedBox(height: 12),
              EditorFormato(
                valorController: _valorController,
                unidades: _unidadesDeFamilia,
                unidadSeleccionada: _unidadNueva,
                onUnidadCambio: (unidad) {
                  if (unidad == null) return;
                  setState(() {
                    _unidadNueva = unidad;
                    _error = null;
                  });
                },
                onValorCambio: () {
                  if (_error != null) setState(() => _error = null);
                },
                onAgregar: _agregarFormato,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('error-editor-presentacion'),
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              PrevisualizacionPresentacion(
                nombre: _nombreEditable
                    ? (colapsarEspacios(_nombreController.text).isEmpty
                          ? _nombre
                          : colapsarEspacios(_nombreController.text))
                    : _nombre,
                formatos: _formatos,
              ),
              if (!_esNueva) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const Key('switch-activa-presentacion'),
                  value: _activa,
                  onChanged: _obligatoria
                      ? null
                      : (activa) => setState(() => _activa = activa),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tituloSwitch,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        ElevatedButton(
          key: const Key('guardar-editor-presentacion'),
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class EditorFormato extends StatelessWidget {
  final TextEditingController valorController;
  final List<UnidadRegistrada> unidades;
  final UnidadRegistrada unidadSeleccionada;
  final ValueChanged<UnidadRegistrada?> onUnidadCambio;
  final VoidCallback onValorCambio;
  final VoidCallback onAgregar;

  const EditorFormato({
    super.key,
    required this.valorController,
    required this.unidades,
    required this.unidadSeleccionada,
    required this.onUnidadCambio,
    required this.onValorCambio,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    final campoValor = TextField(
      key: const Key('campo-valor-formato'),
      controller: valorController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.texto),
      decoration: const InputDecoration(
        labelText: 'Valor',
        hintText: 'Ej: 650',
      ),
      onChanged: (_) => onValorCambio(),
    );
    final campoUnidad = InputDecorator(
      key: const Key('campo-unidad-formato'),
      decoration: const InputDecoration(labelText: 'Unidad'),
      child: DropdownButton<UnidadRegistrada>(
        value: unidadSeleccionada,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        selectedItemBuilder: (context) => [
          for (final unidad in unidades)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                unidad.nombre,
                style: const TextStyle(color: AppColors.texto, fontSize: 16),
              ),
            ),
        ],
        items: [
          for (final unidad in unidades)
            DropdownMenuItem(
              value: unidad,
              child: Text(
                unidad.nombre,
                style: const TextStyle(color: AppColors.texto, fontSize: 16),
              ),
            ),
        ],
        onChanged: onUnidadCambio,
      ),
    );
    final botonAgregar = IconButton.filledTonal(
      key: const Key('boton-agregar-formato'),
      tooltip: 'Agregar formato',
      onPressed: onAgregar,
      icon: const Icon(Icons.add),
    );

    if (MediaQuery.sizeOf(context).width >= 520) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: campoValor),
          const SizedBox(width: 10),
          Expanded(child: campoUnidad),
          const SizedBox(width: 8),
          botonAgregar,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        campoValor,
        const SizedBox(height: 10),
        campoUnidad,
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: botonAgregar),
      ],
    );
  }
}

class _FilaFormatoExistente extends StatelessWidget {
  final FormatoPresentacion formato;
  final bool puedeEliminar;
  final VoidCallback onEliminar;

  const _FilaFormatoExistente({
    required this.formato,
    required this.puedeEliminar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formato.etiqueta,
              key: Key('formato-existente-${formato.etiqueta}'),
              style: const TextStyle(color: AppColors.texto, fontSize: 13),
            ),
          ),
          IconButton(
            key: Key('eliminar-formato-${formato.etiqueta}'),
            tooltip: puedeEliminar
                ? 'Quitar ${formato.etiqueta}'
                : 'No puedes quitar el único formato',
            onPressed: puedeEliminar ? onEliminar : null,
            icon: Icon(
              Icons.delete_outline,
              color: puedeEliminar ? AppColors.error : AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

String _etiquetaFamilia(FamiliaUnidad familia) => switch (familia) {
  FamiliaUnidad.conteo => 'Conteo (unidad)',
  FamiliaUnidad.peso => 'Peso',
  FamiliaUnidad.volumen => 'Volumen',
  FamiliaUnidad.longitud => 'Longitud',
  FamiliaUnidad.area => 'Área',
};

// ═════════════════════════════════════════════════════════════════════════
// Previsualización de presentación
// ═════════════════════════════════════════════════════════════════════════

class PrevisualizacionPresentacion extends StatelessWidget {
  final String nombre;
  final List<FormatoPresentacion> formatos;

  const PrevisualizacionPresentacion({
    super.key,
    required this.nombre,
    required this.formatos,
  });

  @override
  Widget build(BuildContext context) {
    if (formatos.isEmpty) return const SizedBox.shrink();
    final formato = formatos.last;
    final tieneConteoUnitario =
        formato.familia == FamiliaUnidad.conteo && formato.valorBase == 1;
    final titulo = tieneConteoUnitario ? nombre : '$nombre ${formato.etiqueta}';
    final lineaContenido = switch (formato.familia) {
      FamiliaUnidad.conteo => null,
      FamiliaUnidad.volumen => 'El contenido no se descontará en ml.',
      FamiliaUnidad.peso => 'El contenido no se descontará en gramos.',
      FamiliaUnidad.longitud => 'El contenido no se descontará en milímetros.',
      FamiliaUnidad.area => 'El contenido no se descontará en cm².',
    };

    return Container(
      key: const Key('previsualizacion-presentacion'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cómo lo verá el cliente',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Se vende completa.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (lineaContenido != null)
            Text(
              lineaContenido,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}