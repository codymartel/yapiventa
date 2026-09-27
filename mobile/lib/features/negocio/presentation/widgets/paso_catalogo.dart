import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/encabezado_pantalla.dart';
import '../../../productos/domain/models/familia_unidad.dart';
import '../../domain/models/categoria_personalizada.dart';
import '../../domain/models/catalogo_venta/catalogo_venta_global.dart';
import '../../domain/models/catalogo_venta/formato_presentacion.dart';
import '../../domain/models/catalogo_venta/opcion_presentacion.dart';
import '../../domain/models/catalogo_venta/preset_venta_rubro.dart';
import '../../domain/models/catalogo_venta/unidad_registrada.dart';
import '../providers/configuracion_negocio_provider.dart';
import 'seccion_medidas.dart';
import 'seccion_resumen_catalogo.dart';

// ═════════════════════════════════════════════════════════════════════════
// PasoCatalogo — Paso 2 del wizard: "Catálogo"
// ═════════════════════════════════════════════════════════════════════════
//
// El interior del paso se organiza en tres pestañas:
//   - "Categorías": diseño nuevo con cabecera (título + contador + botón),
//     tarjetas de categorías sugeridas y personalizadas, y diálogos con
//     validación mejorada.
//   - "Presentaciones": cómo se presenta y se vende cada producto, con el
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

class PasoCatalogo extends StatelessWidget {
  /// Identidad del usuario: la usan las escrituras de categorías.
  final String uid;

  const PasoCatalogo({super.key, this.uid = ''});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SelectorPestanas(
          activa: p.catalogoPestana,
          onCambiar: p.cambiarCatalogoPestana,
        ),
        const SizedBox(height: 14),
        if (p.catalogoPestana == 1)
          const SeccionPresentaciones()
        else if (p.catalogoPestana == 2)
          const SeccionMedidas()
        else
          _PanelCategorias(uid: uid),
        const SizedBox(height: 24),
        const SeccionResumenCatalogo(),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Selector de pestañas (Categorías / Presentaciones / Medidas)
// ═════════════════════════════════════════════════════════════════════════
// Las tres pestañas responden a lo que la persona configura en el catálogo:
//   - Categorías: cómo organiza sus productos.
//   - Presentaciones: cómo se presenta y se vende (unidad, botella, caja,
//     paquete, set…).
//   - Medidas: venta por peso, volumen, longitud o área.
//
// Escritorio: alto 46 px, ancho máximo 500 px, las tres del mismo ancho.
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
          height: 46,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
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
                  etiqueta: 'Presentaciones',
                  icono: Icons.inventory_2_outlined,
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
    // Activa en blanco sobre el fondo azul; inactiva apagada. Es el contraste
    // del fondo, no el tamaño, lo que marca en cuál está la persona.
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
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 15, color: colorTexto),
                  const SizedBox(width: 5),
                  Text(
                    etiqueta,
                    maxLines: 1,
                    style: TextStyle(
                      color: colorTexto,
                      fontSize: 13,
                      fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
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
//
// Lee el catálogo de las TRES fuentes explícitas, sin deducir el origen de
// ninguna categoría por comparación de strings:
//
//   - Preset del rubro      → PresetsVenta.obtener(rubro).categorias
//   - Estado del preset     → categoriaPresetDesactivada (categoriasDesactivadas)
//   - Personalizadas        → categoriasPersonalizadas (clave, nombre, activa)
//
// `_categorias` (el borrador legacy) ya no participa en decidir qué es preset y
// qué es personalizada; sigue existiendo para el guardado y para las
// validaciones del wizard, sin tocar.
//
// DISEÑO: dos secciones —"Sugeridas para {rubro}" y "Tus categorías"— con
// tarjetas compactas de una sola fila. El rótulo "Sugerida para {rubro}" ya
// no se repite en cada tarjeta porque lo dice el encabezado de sección. Los
// iconos salen de una tabla EXPLÍCITA de los nombres conocidos del preset: no
// se deducen del texto, y las personalizadas no llevan icono propio.
// ═════════════════════════════════════════════════════════════════════════

/// Iconos de las categorías CONOCIDAS del preset.
///
/// Tabla explícita y cerrada. Un nombre que no esté aquí produce una tarjeta
/// sin icono, no un icono adivinado: así una categoría nueva del preset nunca
/// recibe un semántico arbitrario.
const Map<String, IconData> _iconosPresetConocidos = {
  'Abarrotes': Icons.inventory_2_outlined,
  'Bebidas': Icons.local_drink_outlined,
  'Snacks': Icons.cookie_outlined,
  'Limpieza': Icons.cleaning_services_outlined,
  'Cuidado personal': Icons.spa_outlined,
  'Entradas': Icons.restaurant_outlined,
  'Platos principales': Icons.dinner_dining_outlined,
  'Postres': Icons.icecream_outlined,
  'Combos': Icons.lunch_dining_outlined,
  'Hombre': Icons.checkroom_outlined,
  'Mujer': Icons.checkroom_outlined,
  'Niños': Icons.child_care_outlined,
  'Calzado': Icons.ice_skating_outlined,
  'Accesorios': Icons.watch_outlined,
  'Bisutería': Icons.diamond_outlined,
  'Carteras': Icons.shopping_bag_outlined,
  'Peluches': Icons.toys_outlined,
  'Regalos': Icons.card_giftcard_outlined,
  'Detalles': Icons.auto_awesome_outlined,
  'Cabello': Icons.content_cut_outlined,
  'Rostro': Icons.face_retouching_natural_outlined,
  'Cuerpo': Icons.accessibility_new_outlined,
  'Maquillaje': Icons.brush_outlined,
  'Perfumería': Icons.local_florist_outlined,
  'Productos': Icons.category_outlined,
  'Servicios relacionados': Icons.handyman_outlined,
  'Otros': Icons.more_horiz_outlined,
};

class _PanelCategorias extends StatelessWidget {
  final String uid;

  const _PanelCategorias({required this.uid});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    final presetCategorias = PresetsVenta.obtener(p.rubro).categorias;
    final personalizadas = p.categoriasPersonalizadas;

    final sugeridasActivas = presetCategorias
        .where((nombre) => !p.categoriaPresetDesactivada(nombre))
        .length;
    final propiasActivas = personalizadas
        .where((categoria) => categoria.activa)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera de la pestaña ────────────────────────────────────────
        // Título + contador a la izquierda y el botón pegado al BORDE
        // DERECHO del contenido, el mismo que cierra las tarjetas.
        //
        // El botón va como hijo normal del Row (no `Flexible`) y el texto es el
        // único que `Expanded`: así todo el espacio sobrante se lo queda el
        // texto y el botón queda al extremo, en vez de flotar a media anchura.
        LayoutBuilder(
          builder: (context, constraints) {
            final textos = EncabezadoPantalla.sinPadding(
              // No repite "Categorías": ese nombre ya está en la pestaña activa.
              titulo: 'Organiza tus productos',
              subtitulo:
                  '${sugeridasActivas + propiasActivas} activas · '
                  '${presetCategorias.length} sugeridas · '
                  '$propiasActivas ${propiasActivas == 1 ? 'propia' : 'propias'}',
            );
            final boton = _BotonNuevaCategoria(
              onNueva: () =>
                  _dialogoGuardarCategoria(context, uid: uid, nuevo: true),
            );
            // El botón solo se queda a la derecha del título cuando caben los
            // dos; si no, baja debajo. La cuenta se hace con la escala de texto
            // activa porque con el texto muy ampliado el rótulo ocupa bastante
            // más y empujarlo a la fila lo desbordaría.
            final escala = MediaQuery.textScalerOf(context).scale(1);
            final enFila = constraints.maxWidth >= 16 + 310 * escala;
            if (!enFila) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  textos,
                  const SizedBox(height: 10),
                  boton,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: textos),
                const SizedBox(width: 16),
                boton,
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 700 ? 2 : 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SeccionCategorias(
                  clave: 'seccion-sugeridas',
                  titulo: 'Sugeridas para ${p.rubro}',
                  contador: '$sugeridasActivas de ${presetCategorias.length}',
                  child: _GrillaCategorias(
                    columnas: columnas,
                    hijos: [
                      for (final nombre in presetCategorias)
                        _TarjetaPreset(
                          nombre: nombre,
                          activa: !p.categoriaPresetDesactivada(nombre),
                          onActivar: () => _alternarCategoria(
                            context,
                            () => p.reactivarCategoriaDelPreset(uid, nombre),
                          ),
                          onDesactivar: () => _alternarCategoria(
                            context,
                            () => p.desactivarCategoriaDelPreset(uid, nombre),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SeccionCategorias(
                  clave: 'seccion-propias',
                  titulo: 'Tus categorías',
                  contador: propiasActivas == personalizadas.length
                      ? '$propiasActivas'
                      : '$propiasActivas de ${personalizadas.length}',
                  child: personalizadas.isEmpty
                      ? const _SinCategoriasPropias()
                      : _GrillaCategorias(
                          columnas: columnas,
                          hijos: [
                            for (final categoria in personalizadas)
                              _TarjetaPropia(
                                clave: categoria.clave,
                                nombre: categoria.nombre,
                                activa: categoria.activa,
                                onEditar: () => _intentarEditar(
                                  context,
                                  uid,
                                  categoria.clave,
                                  categoria.nombre,
                                ),
                                onAlternar: () => _alternarCategoria(
                                  context,
                                  categoria.activa
                                      ? () => p
                                            .desactivarCategoriaPersonalizada(
                                              uid,
                                              categoria.clave,
                                            )
                                      : () => p
                                            .reactivarCategoriaPersonalizada(
                                              uid,
                                              categoria.clave,
                                            ),
                                ),
                                onEliminar: () => _intentarEliminar(
                                  context,
                                  uid,
                                  categoria.clave,
                                  categoria.nombre,
                                ),
                              ),
                          ],
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

/// Encabezado de sección: título a la izquierda, conteo a la derecha.
class _SeccionCategorias extends StatelessWidget {
  final String clave;
  final String titulo;
  final String contador;
  final Widget child;

  const _SeccionCategorias({
    required this.clave,
    required this.titulo,
    required this.contador,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key(clave),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                contador,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Rejilla responsive compartida por las dos secciones.
class _GrillaCategorias extends StatelessWidget {
  final int columnas;
  final List<Widget> hijos;

  const _GrillaCategorias({required this.columnas, required this.hijos});

  @override
  Widget build(BuildContext context) {
    if (hijos.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho =
            (constraints.maxWidth - 10 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hijo in hijos)
              SizedBox(width: ancho, child: hijo),
          ],
        );
      },
    );
  }
}

/// Tarjeta de una categoría del preset: nombre, estado e interruptor.
class _TarjetaPreset extends StatelessWidget {
  final String nombre;
  final bool activa;
  final VoidCallback onActivar;
  final VoidCallback onDesactivar;

  const _TarjetaPreset({
    required this.nombre,
    required this.activa,
    required this.onActivar,
    required this.onDesactivar,
  });

  @override
  Widget build(BuildContext context) {
    final icono = _iconosPresetConocidos[nombre];
    return _CajaCategoria(
      clave: 'categoria-card-$nombre',
      child: Row(
        children: [
          if (icono != null) ...[
            _IconoNota(icono: icono),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                _EstadoActiva(activa: activa),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Flexible para que con texto muy ampliado la acción ceda espacio en
          // lugar de desbordar la tarjeta.
          Flexible(
            child: _BotonInterruptor(
              activa: activa,
              onPressed: activa ? onDesactivar : onActivar,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de una categoría propia: sin icono semántico, con `Editar` y un
/// menú `...` que agrupa Activar/Desactivar y Eliminar.
class _TarjetaPropia extends StatelessWidget {
  final String clave;
  final String nombre;
  final bool activa;
  final VoidCallback onEditar;
  final VoidCallback onAlternar;
  final VoidCallback onEliminar;

  const _TarjetaPropia({
    required this.clave,
    required this.nombre,
    required this.activa,
    required this.onEditar,
    required this.onAlternar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return _CajaCategoria(
      // Se identifica por `clave`, no por nombre: una propia puede llamarse
      // igual que una sugerida y las dos tarjetas deben seguir siendo distintas.
      clave: 'categoria-propia-$clave',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                _EstadoActiva(activa: activa),
              ],
            ),
          ),
          Flexible(
            child: _BotonMenudo(
              etiqueta: 'Editar',
              onPressed: onEditar,
              tooltip: 'Editar $nombre',
            ),
          ),
          PopupMenuButton<String>(
            key: Key('menu-categoria-$clave'),
            tooltip: 'Más acciones de $nombre',
            icon: const Icon(Icons.more_horiz, size: 18),
            padding: EdgeInsets.zero,
            color: AppColors.superficie,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppColors.border),
            ),
            onSelected: (opcion) {
              if (opcion == 'alternar') onAlternar();
              if (opcion == 'eliminar') onEliminar();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'alternar',
                // Key propia: el rótulo 'Desactivar'/'Activar' también existe en
                // las tarjetas sugeridas y el finder debe poder aislar el menú.
                key: const ValueKey('menu-item-alternar'),
                child: Text(activa ? 'Desactivar' : 'Activar'),
              ),
              PopupMenuItem<String>(
                value: 'eliminar',
                key: const ValueKey('menu-item-eliminar'),
                child: Text(
                  'Eliminar',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Contenedor visual común: una sola tarjeta, una sola fila, sin subtítulo
/// repetido y con el mínimo padding vertical.
class _CajaCategoria extends StatelessWidget {
  final String clave;
  final Widget child;

  const _CajaCategoria({required this.clave, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key(clave),
      color: AppColors.card,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

class _IconoNota extends StatelessWidget {
  final IconData icono;

  const _IconoNota({required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icono, size: 16, color: AppColors.blueLt),
    );
  }
}

class _EstadoActiva extends StatelessWidget {
  final bool activa;

  const _EstadoActiva({required this.activa});

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.blueLt : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        // Flexible para que un nombre largo con texto ampliado nunca desborde la
        // tarjeta: se recorta en lugar de empujar el interruptor.
        Flexible(
          child: Text(
            activa ? 'Activa' : 'Inactiva',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _BotonInterruptor extends StatelessWidget {
  final bool activa;
  final VoidCallback onPressed;

  const _BotonInterruptor({required this.activa, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blueLt,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        activa ? 'Desactivar' : 'Activar',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BotonMenudo extends StatelessWidget {
  final String etiqueta;
  final VoidCallback onPressed;
  final String tooltip;

  const _BotonMenudo({
    required this.etiqueta,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blueLt,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _BotonNuevaCategoria extends StatelessWidget {
  final VoidCallback onNueva;

  const _BotonNuevaCategoria({required this.onNueva});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Agregar categoría',
      child: FilledButton.icon(
        key: const Key('boton-nueva-categoria'),
        onPressed: onNueva,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Nueva categoría'),
      ),
    );
  }
}

class _SinCategoriasPropias extends StatelessWidget {
  const _SinCategoriasPropias();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Todavía no has creado categorías propias. Usa "Nueva categoría" '
        'para añadir las que necesite tu negocio.',
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════

void _mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// Activa o desactiva una categoría y comunica el motivo del rechazo.
///
/// El provider es quien decide (es el que protege la regla de integridad);
/// esta capa solo lee `errorCatalogo` y lo muestra, para que un rechazo nunca
/// sea silencioso.
Future<void> _alternarCategoria(
  BuildContext context,
  Future<bool> Function() operacion,
) async {
  final p = context.read<ConfiguracionNegocioProvider>();
  p.limpiarErrorCatalogo();
  final ok = await operacion();
  if (!context.mounted || ok) return;
  final error = p.errorCatalogo;
  if (error != null) _mostrarMensaje(context, error);
}

/// Renombrar una personalizada: la clave es su identidad y no se recalcula,
/// por eso la busca el provider por `clave` y no por el nombre visible.
Future<void> _intentarEditar(
  BuildContext context,
  String uid,
  String clave,
  String nombre,
) async {
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
  await _dialogoGuardarCategoria(
    context,
    uid: uid,
    nuevo: false,
    clave: clave,
    nombreActual: nombre,
  );
}

Future<void> _intentarEliminar(
  BuildContext context,
  String uid,
  String clave,
  String nombre,
) async {
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
  await p.eliminarCategoriaPersonalizada(uid, clave);
  if (!context.mounted) return;
  final error = p.errorCatalogo;
  if (error != null) _mostrarMensaje(context, error);
}

// ═════════════════════════════════════════════════════════════════════════
// Formulario de categoría: UN solo componente para el alta y la edición.
//
// Solo cambia lo que la persona ve (título, texto precargado, rótulo del botón
// principal y la ayuda); la validación, la clave canónica y las escrituras son
// exactamente las mismas en los dos estados.
// ═════════════════════════════════════════════════════════════════════════

/// Ayuda visible bajo el campo mientras no haya error.
const String _ayudaNombreCategoria =
    'La categoría aparecerá en Productos y en tu tienda cuando esté activa.';

/// Borde del campo en cada estado. Un solo lugar para el radio y el color.
OutlineInputBorder _bordeCampoCategoria(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(10),
  borderSide: BorderSide(color: color),
);

Future<void> _dialogoGuardarCategoria(
  BuildContext context, {
  required String uid,
  required bool nuevo,
  String? clave,
  String? nombreActual,
}) async {
  final p = context.read<ConfiguracionNegocioProvider>();
  p.limpiarErrorCatalogo();
  await showDialog<void>(
    context: context,
    builder: (_) => _DialogoGuardarCategoria(
      provider: p,
      uid: uid,
      nuevo: nuevo,
      clave: clave,
      nombreActual: nombreActual,
    ),
  );
}

class _DialogoGuardarCategoria extends StatefulWidget {
  const _DialogoGuardarCategoria({
    required this.provider,
    required this.uid,
    required this.nuevo,
    this.clave,
    this.nombreActual,
  });

  final ConfiguracionNegocioProvider provider;
  final String uid;
  final bool nuevo;

  /// Identidad canónica de la personalizada que se renombra. En alta es null.
  final String? clave;

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
  bool _guardando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Persiste contra el provider. Las escrituras son asíncronas (Firestore
  /// primero, memoria después), así que el formulario espera y solo se cierra si
  /// la operación devolvió `true`; si falló, el motivo queda en el propio
  /// formulario en lugar de perder lo que la persona escribió.
  ///
  /// Es el único camino de guardado (botón, Enter y submit): el primer `if`
  /// descarta el doble envío mientras hay una escritura en curso.
  Future<void> _guardar() async {
    if (_guardando) return;
    final p = widget.provider;
    final mensajeError = _validarNombreCategoria(
      p,
      _controller.text,
      clave: widget.clave,
    );
    if (mensajeError != null) {
      setState(() => _error = mensajeError);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    p.limpiarErrorCatalogo();

    final nombre = _colapsarEspacios(_controller.text);
    final ok = widget.nuevo
        ? await p.agregarCategoriaPersonalizada(widget.uid, nombre)
        : await p.renombrarCategoriaPersonalizada(
            widget.uid,
            widget.clave!,
            nombre,
          );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _guardando = false;
        _error = p.errorCatalogo ?? 'No se pudo guardar la categoría.';
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.nuevo;
    return PopScope(
      // Mientras escribe no se cierra: una escritura a medio camino no puede
      // quedar a medias. Escape y "Cancelar" siguen cerrando cuando no guarda.
      canPop: !_guardando,
      child: AlertDialog(
        key: const Key('dialogo-categoria'),
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        // Margen holgado en escritorio, estrecho en móvil: el formulario nunca
        // se convierte en un diálogo enorme.
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        title: Text(
          esNuevo ? 'Nueva categoría' : 'Editar categoría',
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: ConstrainedBox(
          // Tope de ancho en escritorio; en móvil manda el `insetPadding`.
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nombre de la categoría',
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('campo-nombre-categoria'),
                controller: _controller,
                autofocus: true,
                enabled: !_guardando,
                style: const TextStyle(color: AppColors.texto),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Ej. Comida para mascotas',
                  hintStyle: const TextStyle(color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.card,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: _bordeCampoCategoria(AppColors.border),
                  enabledBorder: _bordeCampoCategoria(AppColors.border),
                  focusedBorder: _bordeCampoCategoria(AppColors.blueLt),
                  disabledBorder: _bordeCampoCategoria(AppColors.dim),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                // Enter guarda, igual que el botón principal.
                onSubmitted: (_) => _guardar(),
              ),
              const SizedBox(height: 10),
              // Una sola zona bajo el campo: el error ocupa el lugar de la
              // ayuda, así el formulario no salta de alto al validar.
              if (_error != null)
                Row(
                  key: const Key('error-nombre-categoria'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  _ayudaNombreCategoria,
                  key: const Key('ayuda-nombre-categoria'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('cancelar-categoria'),
            onPressed: _guardando ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('guardar-categoria'),
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: _guardando
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(esNuevo ? 'Crear categoría' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

/// Valida el nombre contra las DOS fuentes explícitas: las personalizadas ya
/// registradas (por `clave` canónica) y el preset del rubro. Una personalizada
/// nunca puede pasar por una categoría del preset.
String? _validarNombreCategoria(
  ConfiguracionNegocioProvider p,
  String textoCrudo, {
  String? clave,
}) {
  final texto = _colapsarEspacios(textoCrudo);
  if (texto.isEmpty) return 'Escribe el nombre de la categoría.';
  if (texto.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
  if (texto.length > 40) return 'El nombre no puede superar los 40 caracteres.';
  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(texto)) {
    return 'El nombre debe incluir letras o números.';
  }
  final objetivo = canonicalizarCategoria(texto);
  for (final categoria in p.categoriasPersonalizadas) {
    if (categoria.clave == clave) continue;
    if (categoria.clave == objetivo) {
      return 'Ya existe una categoría con ese nombre.';
    }
  }
  for (final nombre in PresetsVenta.obtener(p.rubro).categorias) {
    if (canonicalizarCategoria(nombre) == objetivo) {
      return 'Ese nombre ya es una categoría sugerida de ${p.rubro}.';
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
          onNueva: () => _abrirEditor(context, null),
        ),
        const SizedBox(height: 16),
        if (obligatorias.isNotEmpty) ...[
          const _SubtituloSeccion('Obligatorias'),
          // Las obligatorias son pocas y ancho completo: una columna pleine.
          for (final presentacion in obligatorias) ...[
            TarjetaPresentacion(
              presentacion: presentacion,
              onEditar: () => _abrirEditor(context, presentacion.id),
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
                  onEditar: () => _abrirEditor(context, presentacion.id),
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
                  onEditar: () => _abrirEditor(context, presentacion.id),
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

Future<void> _abrirEditor(BuildContext context, String? presentacionId) {
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
