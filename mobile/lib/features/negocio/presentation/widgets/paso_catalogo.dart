import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/categoria.dart';
import '../../../../domain/models/tipo_unidad.dart';
import '../providers/configuracion_negocio_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// PasoCatalogo — Paso 2 del wizard: "Catálogo"
// ═════════════════════════════════════════════════════════════════════════
//
// El interior del paso se organiza en dos pestañas:
//   - "Categorías": diseño nuevo con cabecera (título + contador + botón),
//     tarjetas de categorías sugeridas y personalizadas, y diálogos con
//     validación mejorada.
//   - "Unidades de venta": conserva temporalmente el contenido anterior.
//
// NO escribe Firestore al cambiar de pestaña y NO toca la lógica de
// guardado: el proveedor solo expone helpers de lectura (categoriaActiva,
// desactivarCategoria y categoriaTieneProductos).
// ═════════════════════════════════════════════════════════════════════════

class PasoCatalogo extends StatefulWidget {
  const PasoCatalogo({super.key});

  @override
  State<PasoCatalogo> createState() => _PasoCatalogoState();
}

class _PasoCatalogoState extends State<PasoCatalogo> {
  bool _mostrandoUnidades = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SelectorPestanas(
          categoriasActiva: !_mostrandoUnidades,
          onCambiar: (unidades) =>
              setState(() => _mostrandoUnidades = unidades),
        ),
        const SizedBox(height: 20),
        if (_mostrandoUnidades)
          const _PanelUnidades()
        else
          const _PanelCategorias(),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Selector de pestañas (Categorías / Unidades de venta)
// ═════════════════════════════════════════════════════════════════════════
// Escritorio: alto 52 px, ancho máximo 500 px, cada pestaña la mitad.
// Móvil: ocupa todo el ancho disponible, sin scroll horizontal.
class _SelectorPestanas extends StatelessWidget {
  final bool categoriasActiva;
  final ValueChanged<bool> onCambiar;

  const _SelectorPestanas({
    required this.categoriasActiva,
    required this.onCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth >= 500
            ? 500.0
            : constraints.maxWidth;
        return Container(
          width: ancho,
          height: 52,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _Pestana(
                  clave: 'pestana-categorias',
                  etiqueta: 'Categorías',
                  icono: Icons.category_outlined,
                  activa: categoriasActiva,
                  onTap: () => onCambiar(false),
                ),
              ),
              Expanded(
                child: _Pestana(
                  clave: 'pestana-unidades',
                  etiqueta: 'Unidades de venta',
                  icono: Icons.straighten,
                  activa: !categoriasActiva,
                  onTap: () => onCambiar(true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pestana extends StatelessWidget {
  final String clave;
  final String etiqueta;
  final IconData icono;
  final bool activa;
  final VoidCallback onTap;

  const _Pestana({
    required this.clave,
    required this.etiqueta,
    required this.icono,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = activa ? Colors.white : AppColors.texto;
    return Material(
      key: Key(clave),
      color: activa ? AppColors.blue : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 20, color: colorTexto),
                  const SizedBox(width: 8),
                  Text(
                    etiqueta,
                    style: TextStyle(
                      color: colorTexto,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Panel de Categorías
// ═════════════════════════════════════════════════════════════════════════
class _PanelCategorias extends StatelessWidget {
  const _PanelCategorias();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    final presets = Categorias.obtener(p.rubro);
    final personalizadas = p.categorias
        .where((nombre) => !presets.contains(nombre))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CabeceraCategorias(
          cantidadActivas: p.categorias.length,
          onNueva: () => _dialogoGuardarCategoria(context, nuevo: true),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final dosColumnas = constraints.maxWidth >= 720;
            final ancho = dosColumnas
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final nombre in presets)
                  SizedBox(
                    width: ancho,
                    child: _CategoriaCard(
                      clave: 'categoria-card-$nombre',
                      nombre: nombre,
                      subtitulo: 'Sugerida para ${p.rubro}',
                      activa: p.categoriaActiva(nombre),
                      esSugerida: true,
                      anchoLocal: constraints.maxWidth,
                      onActivar: () => p.agregarCategoria(nombre),
                      onDesactivar: () => _intentarDesactivar(context, nombre),
                    ),
                  ),
                for (final nombre in personalizadas)
                  SizedBox(
                    width: ancho,
                    child: _CategoriaCard(
                      clave: 'categoria-card-$nombre',
                      nombre: nombre,
                      subtitulo: 'Personalizada',
                      activa: true,
                      esSugerida: false,
                      anchoLocal: constraints.maxWidth,
                      onEditar: () => _intentarEditar(context, nombre),
                      onEliminar: () => _intentarEliminar(context, nombre),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// Cabecera de Categorías: título + descripción a la izquierda, contador y
// botón a la derecha en escritorio; apilados bajo 600 px.
class _CabeceraCategorias extends StatelessWidget {
  final int cantidadActivas;
  final VoidCallback onNueva;

  const _CabeceraCategorias({
    required this.cantidadActivas,
    required this.onNueva,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = Text(
      'Categorías de productos',
      style: TextStyle(
        color: AppColors.texto,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
    final descripcion = Text(
      'Organizan tus productos para que tus clientes los encuentren fácilmente.',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: AppColors.muted, fontSize: 13),
    );
    final contador = Text(
      '$cantidadActivas activas',
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    final boton = Tooltip(
      message: 'Agregar categoría',
      child: OutlinedButton(
        onPressed: onNueva,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: AppColors.blueLt,
          side: const BorderSide(color: Colors.transparent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Text(
          '+ Nueva categoría',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titulo, const SizedBox(height: 4), descripcion],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [contador, const SizedBox(height: 16), boton],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titulo,
            const SizedBox(height: 4),
            descripcion,
            const SizedBox(height: 12),
            contador,
            const SizedBox(height: 16),
            boton,
          ],
        );
      },
    );
  }
}

// Tarjeta de una categoría (sugerida del rubro o personalizada).
class _CategoriaCard extends StatelessWidget {
  final String clave;
  final String nombre;
  final String subtitulo;
  final bool activa;
  final bool esSugerida;
  final double anchoLocal;
  final VoidCallback? onActivar;
  final VoidCallback? onDesactivar;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  const _CategoriaCard({
    required this.clave,
    required this.nombre,
    required this.subtitulo,
    required this.activa,
    required this.esSugerida,
    required this.anchoLocal,
    this.onActivar,
    this.onDesactivar,
    this.onEditar,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final tactil = anchoLocal < 480;
    final acciones = <Widget>[
      if (esSugerida)
        _BotonAccionTarjeta(
          etiqueta: activa ? 'Desactivar' : 'Activar',
          tactil: tactil,
          onPressed: activa ? onDesactivar : onActivar,
        )
      else ...[
        _BotonAccionTarjeta(
          etiqueta: 'Editar',
          tactil: tactil,
          onPressed: onEditar,
        ),
        _BotonAccionTarjeta(
          etiqueta: 'Eliminar',
          color: AppColors.error,
          tactil: tactil,
          onPressed: onEliminar,
        ),
      ],
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 84),
      child: Material(
        key: Key(clave),
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _EstadoCategoria(activa: activa),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: acciones,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoCategoria extends StatelessWidget {
  final bool activa;

  const _EstadoCategoria({required this.activa});

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.blueLt : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(
          activa ? 'Activa' : 'Inactiva',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BotonAccionTarjeta extends StatelessWidget {
  final String etiqueta;
  final VoidCallback? onPressed;
  final Color color;
  final bool tactil;

  const _BotonAccionTarjeta({
    required this.etiqueta,
    required this.tactil,
    this.onPressed,
    this.color = AppColors.blueLt,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: tactil ? const Size(48, 48) : const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        etiqueta,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Acciones de categorías
// ═════════════════════════════════════════════════════════════════════════

void _mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

Future<void> _intentarDesactivar(BuildContext context, String nombre) async {
  final p = context.read<ConfiguracionNegocioProvider>();
  if (p.categorias.length <= 1) {
    _mostrarMensaje(
      context,
      'No puedes desactivar todas las categorías. Mantén al menos una activa.',
    );
    return;
  }
  p.desactivarCategoria(nombre);
}

Future<void> _intentarEditar(BuildContext context, String nombre) async {
  final p = context.read<ConfiguracionNegocioProvider>();
  if (await p.categoriaTieneProductos(nombre)) {
    if (!context.mounted) return;
    _mostrarMensaje(
      context,
      'Esta categoría está siendo usada por productos. '
      'Cambia primero esos productos a otra categoría.',
    );
    return;
  }
  if (!context.mounted) return;
  await _dialogoGuardarCategoria(context, nuevo: false, nombreActual: nombre);
}

Future<void> _intentarEliminar(BuildContext context, String nombre) async {
  final p = context.read<ConfiguracionNegocioProvider>();
  if (await p.categoriaTieneProductos(nombre)) {
    if (!context.mounted) return;
    _mostrarMensaje(
      context,
      'Esta categoría está siendo usada por productos. '
      'Cambia primero esos productos a otra categoría.',
    );
    return;
  }
  if (!context.mounted) return;
  if (p.categorias.length <= 1) {
    _mostrarMensaje(
      context,
      'No puedes desactivar todas las categorías. Mantén al menos una activa.',
    );
    return;
  }
  final procede = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.superficie,
      title: Text(
        '¿Eliminar $nombre?',
        style: const TextStyle(color: AppColors.texto),
      ),
      content: const Text(
        'Esta categoría dejará de estar disponible al crear productos.',
        style: TextStyle(color: AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (!context.mounted || procede != true) return;
  final index = p.categorias.indexOf(nombre);
  if (index != -1) p.eliminarCategoria(index);
}

// Diálogo reutilizable para nueva/edición de categoría con validación.
Future<void> _dialogoGuardarCategoria(
  BuildContext context, {
  required bool nuevo,
  String? nombreActual,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _DialogoGuardarCategoria(nuevo: nuevo, nombreActual: nombreActual),
  );
}

class _DialogoGuardarCategoria extends StatefulWidget {
  const _DialogoGuardarCategoria({required this.nuevo, this.nombreActual});

  final bool nuevo;
  final String? nombreActual;

  @override
  State<_DialogoGuardarCategoria> createState() =>
      _DialogoGuardarCategoriaState();
}

class _DialogoGuardarCategoriaState extends State<_DialogoGuardarCategoria> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.nombreActual ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      title: Text(
        widget.nuevo ? 'Nueva categoría' : 'Editar categoría',
        style: const TextStyle(color: AppColors.texto),
      ),
      content: TextField(
        key: const Key('campo-nombre-categoria'),
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.texto),
        decoration: InputDecoration(
          labelText: 'Nombre de la categoría',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
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
          onPressed: () {
            final p = context.read<ConfiguracionNegocioProvider>();
            final mensajeError = _validarNombreCategoria(
              p,
              _controller.text,
              nombreActual: widget.nombreActual,
            );
            if (mensajeError != null) {
              setState(() => _error = mensajeError);
              return;
            }
            final nombre = _colapsarEspacios(_controller.text);
            if (widget.nuevo) {
              p.agregarCategoria(nombre);
            } else {
              final index = p.categorias.indexOf(widget.nombreActual ?? '');
              if (index != -1) p.editarCategoria(index, nombre);
            }
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

String? _validarNombreCategoria(
  ConfiguracionNegocioProvider p,
  String textoCrudo, {
  String? nombreActual,
}) {
  final texto = _colapsarEspacios(textoCrudo);
  if (texto.isEmpty) return 'Escribe el nombre de la categoría.';
  if (texto.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
  if (texto.length > 40) return 'El nombre no puede superar los 40 caracteres.';
  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(texto)) {
    return 'El nombre debe incluir letras o números.';
  }
  final objetivo = _normalizarNombreCategoria(texto);
  final existentes = <String>{...p.categorias, ...Categorias.obtener(p.rubro)};
  for (final existente in existentes) {
    if (nombreActual != null && existente == nombreActual) continue;
    if (_normalizarNombreCategoria(existente) == objetivo) {
      return 'Ya existe una categoría con ese nombre.';
    }
  }
  return null;
}

String _colapsarEspacios(String texto) =>
    texto.trim().replaceAll(RegExp(r'\s+'), ' ');

// Normaliza para comparar duplicados ignorando mayúsculas, espacios y tildes.
String _normalizarNombreCategoria(String texto) {
  const conTilde = 'áéíóúüñÁÉÍÓÚÜÑ';
  const sinTilde = 'aeiouunAEIOUUN';
  var normalizado = _colapsarEspacios(texto).toLowerCase();
  for (var i = 0; i < conTilde.length; i++) {
    normalizado = normalizado.replaceAll(conTilde[i], sinTilde[i]);
  }
  return normalizado;
}

// ═════════════════════════════════════════════════════════════════════════
// Panel de Unidades de venta (contenido anterior, conservado temporalmente)
// ═════════════════════════════════════════════════════════════════════════

class _PanelUnidades extends StatelessWidget {
  const _PanelUnidades();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unidades de medida',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const Text(
          'Personaliza cómo mides tus productos',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, constraints) {
            const separacion = 12.0;
            final columnas = constraints.maxWidth >= 680 ? 2 : 1;
            final ancho =
                (constraints.maxWidth - separacion * (columnas - 1)) / columnas;
            return Wrap(
              spacing: separacion,
              runSpacing: separacion,
              children: [
                for (final unidad in p.unidadesPredefinidas)
                  SizedBox(
                    width: ancho,
                    child: _UnidadPredefinidaCard(
                      unidad: unidad,
                      activa: p.unidadPredefinidaActiva(unidad.nombre),
                      onChanged: (activa) =>
                          p.establecerUnidadPredefinidaActiva(
                            unidad,
                            activa: activa,
                          ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Unidades personalizadas',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < p.unidadesMedida.length; i++)
              if (!p.unidadPredefinida(p.unidadesMedida[i]))
                InputChip(
                  backgroundColor: AppColors.card,
                  label: Text(
                    p.unidadesMedida[i].nombre,
                    style: TextStyle(color: AppColors.texto, fontSize: 13),
                  ),
                  tooltip: 'Editar ${p.unidadesMedida[i].nombre}',
                  deleteButtonTooltipMessage:
                      'Eliminar ${p.unidadesMedida[i].nombre}',
                  onPressed: () => _dialogoUnidad(context, p, index: i),
                  onDeleted: () => p.eliminarUnidad(i),
                ),
            OutlinedButton.icon(
              onPressed: () => _dialogoUnidad(context, p),
              icon: const Icon(Icons.add),
              label: const Text('Agregar unidad'),
            ),
          ],
        ),
        if (p.faltaUnidad)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Activa o agrega al menos una unidad',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _dialogoUnidad(
    BuildContext context,
    ConfiguracionNegocioProvider p, {
    int? index,
  }) {
    final unidadActual = index != null ? p.unidadesMedida[index] : null;
    final nombreController = TextEditingController(
      text: unidadActual?.nombre ?? '',
    );
    final fraccionesController = TextEditingController(
      text: unidadActual?.fraccionesPermitidas.join(', ') ?? '',
    );
    var tipoSeleccionado = unidadActual?.tipo ?? TipoUnidad.fraccionaria;
    String? errorFracciones;

    return showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.superficie,
          title: Text(
            index == null ? 'Nueva unidad' : 'Editar unidad',
            style: const TextStyle(color: AppColors.texto),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(color: AppColors.texto),
                decoration: const InputDecoration(
                  labelText: 'Nombre (ej: kg, litro, unidad)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<TipoUnidad>(
                      title: const Text(
                        'Fraccionaria',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: TipoUnidad.fraccionaria,
                      groupValue: tipoSeleccionado,
                      onChanged: (v) => setState(() => tipoSeleccionado = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<TipoUnidad>(
                      title: const Text(
                        'Entera',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: TipoUnidad.entera,
                      groupValue: tipoSeleccionado,
                      onChanged: (v) => setState(() => tipoSeleccionado = v!),
                    ),
                  ),
                ],
              ),
              if (tipoSeleccionado == TipoUnidad.fraccionaria) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: fraccionesController,
                  style: const TextStyle(color: AppColors.texto),
                  onChanged: (_) {
                    if (errorFracciones != null) {
                      setState(() => errorFracciones = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Fracciones permitidas *',
                    hintText: 'Ej: 1/4, 1/2, 1',
                    errorText: errorFracciones,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sepáralas con comas.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ],
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
              onPressed: () {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) return;
                final fracciones = fraccionesController.text
                    .split(',')
                    .map((fraccion) => fraccion.trim())
                    .where((fraccion) => fraccion.isNotEmpty)
                    .toList();
                if (tipoSeleccionado == TipoUnidad.fraccionaria &&
                    fracciones.isEmpty) {
                  setState(
                    () => errorFracciones =
                        'Agrega al menos una fracción permitida.',
                  );
                  return;
                }
                final unidad = UnidadInfo(
                  nombre: nombre,
                  tipo: tipoSeleccionado,
                  fraccionesPermitidas:
                      tipoSeleccionado == TipoUnidad.fraccionaria
                      ? fracciones
                      : const [],
                );
                if (index == null) {
                  p.agregarUnidad(unidad);
                } else {
                  p.editarUnidad(index, unidad);
                }
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nombreController.dispose();
      fraccionesController.dispose();
    });
  }
}

class _UnidadPredefinidaCard extends StatelessWidget {
  final UnidadInfo unidad;
  final bool activa;
  final ValueChanged<bool> onChanged;

  const _UnidadPredefinidaCard({
    required this.unidad,
    required this.activa,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = unidad.tipo == TipoUnidad.entera ? 'Entera' : 'Fraccionaria';
    final cantidades = _cantidadesLegibles(unidad);
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        key: Key('unidad-predefinida-${unidad.nombre}'),
        value: activa,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        title: Text(
          unidad.nombre,
          style: TextStyle(color: AppColors.texto, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipo: $tipo', style: TextStyle(color: AppColors.muted)),
              Text(
                'Opcional: ${unidad.esOpcional ? "Sí" : "No"}',
                style: TextStyle(color: AppColors.muted),
              ),
              Text(
                'Cantidades sugeridas: $cantidades',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _cantidadesLegibles(UnidadInfo unidad) {
    if (unidad.fraccionesPermitidas.isEmpty) return 'Cantidades enteras';
    return unidad.fraccionesPermitidas
        .map((valor) => _cantidadLegible(unidad.nombre, valor))
        .join(', ');
  }

  static String _cantidadLegible(String unidad, String valor) {
    if (unidad == 'Docena') {
      return valor == '0.5' ? 'Media docena' : 'Docena';
    }
    if (unidad == 'Porción') {
      return switch (valor) {
        '0.125' => '⅛ de porción',
        '0.25' => '¼ de porción',
        '0.5' => 'Media porción',
        _ => 'Porción',
      };
    }
    if (unidad == 'kg' || unidad == 'L') {
      final numero = switch (valor) {
        '0.25' => '¼',
        '0.5' => '½',
        '0.75' => '¾',
        '1.5' => '1½',
        '2.5' => '2½',
        _ => valor,
      };
      return '$numero $unidad';
    }
    if (unidad == 'g' || unidad == 'ml') return '$valor $unidad';
    return valor;
  }
}
