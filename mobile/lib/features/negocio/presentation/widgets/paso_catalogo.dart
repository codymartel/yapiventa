import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/categoria.dart';
import '../../../productos/domain/models/familia_unidad.dart';
import '../../domain/models/catalogo_venta/catalogo_venta_global.dart';
import '../../domain/models/catalogo_venta/formato_presentacion.dart';
import '../../domain/models/catalogo_venta/opcion_presentacion.dart';
import '../../domain/models/catalogo_venta/unidad_registrada.dart';
import '../providers/configuracion_negocio_provider.dart';
import 'seccion_medidas.dart';

// ═════════════════════════════════════════════════════════════════════════
// PasoCatalogo — Paso 2 del wizard: "Catálogo"
// ═════════════════════════════════════════════════════════════════════════
//
// El interior del paso se organiza en tres pestañas:
//   - "Categorías": diseño nuevo con cabecera (título + contador + botón),
//     tarjetas de categorías sugeridas y personalizadas, y diálogos con
//     validación mejorada.
//   - "Unidades de venta": la interfaz "Unidad o presentación" con el
//     catálogo cerrado de presentaciones (obligatorias, "Más opciones" y
//     personalizadas), sus formatos y su editor.
//   - "Medidas": la interfaz "Venta por medida" con las medidas del rubro
//     (peso, volumen, longitud, área) y su editor (mínimo, incremento y
//     cantidades rápidas en la unidad base).
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
  int _pestanasActiva = 0; // 0 Categorías, 1 Unidades de venta, 2 Medidas.

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SelectorPestanas(
          activa: _pestanasActiva,
          onCambiar: (indice) => setState(() => _pestanasActiva = indice),
        ),
        const SizedBox(height: 20),
        if (_pestanasActiva == 1)
          const SeccionPresentaciones()
        else if (_pestanasActiva == 2)
          const SeccionMedidas()
        else
          const _PanelCategorias(),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Selector de pestañas (Categorías / Unidades de venta / Medidas)
// ═════════════════════════════════════════════════════════════════════════
// Escritorio: alto 52 px, ancho máximo 500 px, cada pestaña un tercio.
// Móvil: ocupa todo el ancho disponible, sin scroll horizontal.
class _SelectorPestanas extends StatelessWidget {
  final int activa;
  final ValueChanged<int> onCambiar;

  const _SelectorPestanas({required this.activa, required this.onCambiar});

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
                  activa: activa == 0,
                  onTap: () => onCambiar(0),
                ),
              ),
              Expanded(
                child: _Pestana(
                  clave: 'pestana-unidades',
                  etiqueta: 'Unidades de venta',
                  icono: Icons.straighten,
                  activa: activa == 1,
                  onTap: () => onCambiar(1),
                ),
              ),
              Expanded(
                child: _Pestana(
                  clave: 'pestana-medidas',
                  etiqueta: 'Medidas',
                  icono: Icons.square_foot,
                  activa: activa == 2,
                  onTap: () => onCambiar(2),
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
// Se usa tanto para categorías como para presentaciones personalizadas.
String _normalizarNombreCategoria(String texto) {
  const conTilde = 'áéíóúüñÁÉÍÓÚÜÑ';
  const sinTilde = 'aeiouunAEIOUUN';
  var normalizado = _colapsarEspacios(texto).toLowerCase();
  for (var i = 0; i < conTilde.length; i++) {
    normalizado = normalizado.replaceAll(conTilde[i], sinTilde[i]);
  }
  return normalizado;
}

String _normalizarNombrePresentacion(String texto) =>
    _normalizarNombreCategoria(texto);

// ═════════════════════════════════════════════════════════════════════════
// Sección "Unidad o presentación"
// ═════════════════════════════════════════════════════════════════════════
// Reemplaza el panel de unidades legacy (Entera/Fraccionaria, fracciones por
// comas, unidad escrita libremente). Muestra el catálogo cerrado de
// presentaciones: obligatorias, "Más opciones" (opcionales) y personalizadas,
// con su estado y sus formatos. El editor valida con los mismos criterios
// (y mensajes) que el provider, así que "1000 ml" y "1 L" son el mismo
// formato normalizado.
// ═════════════════════════════════════════════════════════════════════════

class SeccionPresentaciones extends StatelessWidget {
  const SeccionPresentaciones({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    final obligatorias = p.presentaciones
        .where((presentacion) => presentacion.obligatoria)
        .toList();
    final opcionales = p.presentaciones
        .where(
          (presentacion) =>
              !presentacion.obligatoria && !presentacion.personalizada,
        )
        .toList();
    final personalizadas = p.presentaciones
        .where((presentacion) => presentacion.personalizada)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CabeceraPresentaciones(
          cantidadActivas: p.presentaciones
              .where((presentacion) => presentacion.activa)
              .length,
          puedeCrear: p.puedeCrearPresentacionesPersonalizadas,
          onNueva: () => _abrirEditor(context, null),
        ),
        const SizedBox(height: 16),
        if (obligatorias.isNotEmpty) ...[
          const _SubtituloSeccion('Obligatorias'),
          for (final presentacion in obligatorias)
            TarjetaPresentacion(
              presentacion: presentacion,
              onEditar: () => _abrirEditor(context, presentacion.id),
            ),
        ],
        if (opcionales.isNotEmpty) ...[
          const SizedBox(height: 4),
          const _SubtituloSeccion('Más opciones'),
          for (final presentacion in opcionales)
            TarjetaPresentacion(
              presentacion: presentacion,
              onEditar: () => _abrirEditor(context, presentacion.id),
            ),
        ],
        if (personalizadas.isNotEmpty) ...[
          const SizedBox(height: 4),
          const _SubtituloSeccion('Presentaciones personalizadas'),
          for (final presentacion in personalizadas)
            TarjetaPresentacion(
              presentacion: presentacion,
              onEditar: () => _abrirEditor(context, presentacion.id),
            ),
        ],
      ],
    );
  }
}

class _SubtituloSeccion extends StatelessWidget {
  final String texto;

  const _SubtituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.texto,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _CabeceraPresentaciones extends StatelessWidget {
  final int cantidadActivas;
  final bool puedeCrear;
  final VoidCallback onNueva;

  const _CabeceraPresentaciones({
    required this.cantidadActivas,
    required this.puedeCrear,
    required this.onNueva,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = const Text(
      'Unidad o presentación',
      style: TextStyle(
        color: AppColors.texto,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
    final descripcion = const Text(
      'Define en qué forma se vende cada producto: completa, '
      'opcional o personalizada, con sus tamaños.',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: AppColors.muted, fontSize: 13),
    );
    final contador = Text(
      '$cantidadActivas activas',
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
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
                children: [
                  contador,
                  if (puedeCrear) ...[
                    const SizedBox(height: 16),
                    _BotonNuevaPresentacion(onNueva: onNueva),
                  ],
                ],
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
            if (puedeCrear) ...[
              const SizedBox(height: 16),
              _BotonNuevaPresentacion(onNueva: onNueva),
            ],
          ],
        );
      },
    );
  }
}

class _BotonNuevaPresentacion extends StatelessWidget {
  final VoidCallback onNueva;

  const _BotonNuevaPresentacion({required this.onNueva});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Agregar presentación',
      child: OutlinedButton(
        key: const Key('boton-nueva-presentacion'),
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
          '+ Nueva presentación',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class TarjetaPresentacion extends StatelessWidget {
  final OpcionPresentacion presentacion;
  final VoidCallback onEditar;

  const TarjetaPresentacion({
    super.key,
    required this.presentacion,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final etiquetas = presentacion.formatos
        .map((formato) => formato.etiqueta)
        .join('  ·  ');
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Material(
        key: Key('presentacion-card-${presentacion.id}'),
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
              Text(
                presentacion.nombre,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _EstadoPresentacion(activa: presentacion.activa),
                  if (presentacion.obligatoria)
                    const _EtiquetaChip(
                      texto: 'Obligatoria',
                      color: AppColors.blueLt,
                    ),
                  if (presentacion.personalizada)
                    const _EtiquetaChip(
                      texto: 'Personalizada',
                      color: AppColors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Formatos',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                etiquetas,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('editar-presentacion-${presentacion.id}'),
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoPresentacion extends StatelessWidget {
  final bool activa;

  const _EstadoPresentacion({required this.activa});

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

class _EtiquetaChip extends StatelessWidget {
  final String texto;
  final Color color;

  const _EtiquetaChip({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Future<void> _abrirEditor(BuildContext context, String? presentacionId) {
  context.read<ConfiguracionNegocioProvider>().limpiarErrorCatalogo();
  return showDialog<void>(
    context: context,
    builder: (_) => EditorPresentacion(presentacionId: presentacionId),
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
      final titulo = _colapsarEspacios(_nombreController.text);
      if (titulo.isEmpty) {
        return 'El nombre de la presentación no puede estar vacío.';
      }
      final normalizado = _normalizarNombrePresentacion(titulo);
      final p = context.read<ConfiguracionNegocioProvider>();
      final duplicado = p.presentaciones.any(
        (presentacion) =>
            presentacion.id != _id &&
            _normalizarNombrePresentacion(presentacion.nombre) == normalizado,
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
      final titulo = _colapsarEspacios(_nombreController.text);
      p.agregarPresentacionPersonalizada(nombre: titulo, formatos: _formatos);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
      Navigator.pop(context);
      return;
    }

    final actual = p.presentacionPorId(_id)!;
    final titulo = _colapsarEspacios(_nombreController.text);
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
                    ? (_colapsarEspacios(_nombreController.text).isEmpty
                          ? _nombre
                          : _colapsarEspacios(_nombreController.text))
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
