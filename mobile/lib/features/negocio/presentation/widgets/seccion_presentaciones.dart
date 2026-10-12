import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../productos/domain/models/familia_unidad.dart';
import '../../domain/models/catalogo_venta/formato_presentacion.dart';
import '../../domain/models/catalogo_venta/opcion_presentacion.dart';
import '../providers/configuracion_negocio_provider.dart';
import 'editor_presentacion.dart';

// ═════════════════════════════════════════════════════════════════════════
// Sección "Presentaciones"
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
          onNueva: () => abrirEditorPresentacion(context, null),
        ),
        const SizedBox(height: 16),
        if (obligatorias.isNotEmpty) ...[
          const _SubtituloSeccion('Obligatorias'),
          // Las obligatorias son pocas y ancho completo: una columna pleine.
          for (final presentacion in obligatorias) ...[
            TarjetaPresentacion(
              presentacion: presentacion,
              onEditar: () => abrirEditorPresentacion(context, presentacion.id),
              onActivar: () => p.establecerPresentacionActiva(
                presentacion.id,
                activa: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (opcionales.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _SubtituloSeccion('Más opciones'),
          _GrillaPresentaciones(
            hijos: [
              for (final presentacion in opcionales)
                TarjetaPresentacion(
                  presentacion: presentacion,
                  onEditar: () =>
                      abrirEditorPresentacion(context, presentacion.id),
                  onActivar: () => p.establecerPresentacionActiva(
                    presentacion.id,
                    activa: true,
                  ),
                ),
            ],
          ),
        ],
        if (personalizadas.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _SubtituloSeccion('Presentaciones personalizadas'),
          _GrillaPresentaciones(
            hijos: [
              for (final presentacion in personalizadas)
                TarjetaPresentacion(
                  presentacion: presentacion,
                  onEditar: () =>
                      abrirEditorPresentacion(context, presentacion.id),
                  onActivar: () => p.establecerPresentacionActiva(
                    presentacion.id,
                    activa: true,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Rejilla responsive de las tarjetas de presentación.
///
/// Anchos medidos sobre el `maxWidth` disponible (el `ListView` del paso usa
/// `EdgeInsets.all(20)`, así que 1920 px → ~1880, 1366 → ~1326, 768 → ~728 y
/// 375 → ~335):
/// - `>= 1180` → 3 columnas (PC grande y laptops anchas).
/// - `>= 620`  → 2 columnas (laptops medianos y tablets).
/// - resto     → 1 columna (móvil).
class _GrillaPresentaciones extends StatelessWidget {
  final List<Widget> hijos;

  const _GrillaPresentaciones({required this.hijos});

  static const double _separacion = 10;

  int _columnas(double ancho) {
    if (ancho >= 1180) return 3;
    if (ancho >= 620) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (hijos.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = _columnas(constraints.maxWidth);
        final ancho =
            (constraints.maxWidth - _separacion * (columnas - 1)) / columnas;
        return Wrap(
          spacing: _separacion,
          runSpacing: _separacion,
          children: [
            for (final hijo in hijos) SizedBox(width: ancho, child: hijo),
          ],
        );
      },
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
      'Presentaciones',
      style: TextStyle(
        color: AppColors.texto,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
    final descripcion = const Text(
      'Define en qué forma se presenta y se vende cada producto: completa, '
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

/// Tarjeta compacta de una presentación.
///
/// Jerarquía fija: nombre arriba, estado y badges debajo, luego familia +
/// unidades, luego los formatos. La acción (Editar / Activar) va arriba a la
/// derecha y, cuando el ancho no alcanza (móvil con texto grande), pasa a una
/// fila propia para no desbordar.
///
/// Los formatos se acotan a [_maxFormatos] y el resto se resume en `+N`: la
/// altura queda acotada a dos líneas sin importar cuántas unidades tenga.
class TarjetaPresentacion extends StatelessWidget {
  final OpcionPresentacion presentacion;
  final VoidCallback onEditar;
  final VoidCallback? onActivar;

  static const int _maxFormatos = 4;

  /// Ancho mínimo del contenido para que la acción quepa en la misma línea que
  /// el encabezado. Por debajo (o con texto muy grande) la acción baja a una
  /// fila propia en lugar de desbordar.
  static const double _anchoInline = 300;
  static const double _escalaInline = 1.3;

  const TarjetaPresentacion({
    super.key,
    required this.presentacion,
    required this.onEditar,
    this.onActivar,
  });

  @override
  Widget build(BuildContext context) {
    final formatos = presentacion.formatos;
    final visibles = formatos.take(_maxFormatos).toList();
    final restantes = formatos.length - visibles.length;
    final etiquetas = <String>[
      for (final formato in visibles) formato.etiqueta,
      if (restantes > 0) '+$restantes',
    ].join(' · ');
    final lineaUnidades = _lineaFamiliaYUnidades(formatos);

    return Material(
      key: Key('presentacion-card-${presentacion.id}'),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final escala = MediaQuery.textScalerOf(context).scale(1);
            final encabezado = _EncabezadoTarjetaPresentacion(
              presentacion: presentacion,
            );
            final acciones = _AccionesTarjetaPresentacion(
              presentacion: presentacion,
              onEditar: onEditar,
              onActivar: onActivar,
            );
            final inline =
                constraints.maxWidth >= _anchoInline && escala <= _escalaInline;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inline)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: encabezado),
                      const SizedBox(width: 8),
                      acciones,
                    ],
                  )
                else ...[
                  encabezado,
                  const SizedBox(height: 4),
                  acciones,
                ],
                if (lineaUnidades != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    lineaUnidades,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (etiquetas.isNotEmpty) ...[
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
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Volumen · ml / L". `null` cuando la presentación todavía no tiene
/// formatos, para no dejar una línea de encabezado vacía. Si los formatos
/// abarcan más de una familia (p. ej. Lata: 170 g + 355 ml) se listan todas.
String? _lineaFamiliaYUnidades(List<FormatoPresentacion> formatos) {
  if (formatos.isEmpty) return null;
  final familias = <String>{
    for (final formato in formatos) _familiaCorta(formato.familia),
  };
  final unidades = <String>{
    for (final formato in formatos) formato.unidadVisible.nombre,
  };
  return '${familias.join(' / ')} · ${unidades.join(' / ')}';
}

String _familiaCorta(FamiliaUnidad familia) => switch (familia) {
  FamiliaUnidad.conteo => 'Cantidad',
  FamiliaUnidad.peso => 'Peso',
  FamiliaUnidad.volumen => 'Volumen',
  FamiliaUnidad.longitud => 'Longitud',
  FamiliaUnidad.area => 'Área',
};

/// Icono + nombre + estado + badges. Se mantiene separado para poder-USarlo
/// dentro de una `Row` (ancho amplio) o de una `Column` (ancho estrecho).
class _EncabezadoTarjetaPresentacion extends StatelessWidget {
  final OpcionPresentacion presentacion;

  const _EncabezadoTarjetaPresentacion({required this.presentacion});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconoPresentacion(presentacion: presentacion),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                presentacion.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
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
            ],
          ),
        ),
      ],
    );
  }
}

/// Acciones arriba a la derecha. Una presentación inactiva ofrece "Activar"
/// (además de "Editar", que sigue abriendo el editor) y una activa solo
/// "Editar".
class _AccionesTarjetaPresentacion extends StatelessWidget {
  final OpcionPresentacion presentacion;
  final VoidCallback onEditar;
  final VoidCallback? onActivar;

  const _AccionesTarjetaPresentacion({
    required this.presentacion,
    required this.onEditar,
    required this.onActivar,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 0,
      children: [
        if (!presentacion.activa && onActivar != null)
          _BotonTarjetaPresentacion(
            key: Key('activar-presentacion-${presentacion.id}'),
            icono: Icons.toggle_on_outlined,
            etiqueta: 'Activar',
            color: AppColors.blueLt,
            onPressed: onActivar!,
          ),
        _BotonTarjetaPresentacion(
          key: Key('editar-presentacion-${presentacion.id}'),
          icono: Icons.edit_outlined,
          etiqueta: 'Editar',
          color: AppColors.blueLt,
          onPressed: onEditar,
        ),
      ],
    );
  }
}

class _BotonTarjetaPresentacion extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final Color color;
  final VoidCallback onPressed;

  const _BotonTarjetaPresentacion({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // No se usa `TextButton.icon`: su label es un hijo flex *tight*, así que se
    // queda con todo el ancho disponible y deja sin espacio al nombre de la
    // tarjeta. Con `FlexFit.loose` el texto toma solo su ancho intrínseco.
    return Semantics(
      button: true,
      label: etiqueta,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 15, color: color),
              const SizedBox(width: 4),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconoPresentacion extends StatelessWidget {
  final OpcionPresentacion presentacion;

  const _IconoPresentacion({required this.presentacion});

  static IconData _porId(String id) => switch (id) {
    'botella' => Icons.local_drink_outlined,
    'lata' => Icons.local_cafe_outlined,
    'bolsa' => Icons.shopping_bag_outlined,
    'caja' => Icons.inventory_2_outlined,
    'paquete' => Icons.inventory_2,
    'vaso' => Icons.local_drink,
    'jarra' => Icons.sports_bar_outlined,
    'porcion' => Icons.restaurant,
    'plato' => Icons.dinner_dining,
    'combo' => Icons.layers_outlined,
    'par' => Icons.drag_handle,
    'conjunto' => Icons.grid_view_outlined,
    'set' => Icons.collections_outlined,
    'juego' => Icons.extension_outlined,
    'frasco' => Icons.science_outlined,
    'pote' => Icons.spa_outlined,
    'tubo' => Icons.opacity,
    'sachet' => Icons.mail_outline,
    'spray' => Icons.air,
    _ => Icons.sell_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final icono = presentacion.personalizada
        ? Icons.auto_awesome_outlined
        : _porId(presentacion.id);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.blueLt.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icono, size: 16, color: AppColors.blueLt),
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
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            activa ? 'Activa' : 'Inactiva',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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