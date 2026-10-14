import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/configuracion_negocio_provider.dart';
import 'paso_negocio.dart';
import 'paso_catalogo.dart';
import 'paso_logistica.dart';
import 'paso_pagos.dart';

// ═════════════════════════════════════════════════════════════════════════
// ConfiguracionNegocioContent
// ═════════════════════════════════════════════════════════════════════════
// Contenido puro del wizard de 4 pasos. Arma el stepper, muestra el widget del
// paso actual, y los botones de navegación Atrás/Siguiente/Finalizar.
//
// REGLAS DE ESTE WIDGET:
// - NO crea Scaffold, AppBar ni SafeArea (los provee quien lo embebe).
// - NO crea providers — consume el ConfiguracionNegocioProvider que ya
//   existe más arriba (los cuatro pasos dependen de él).
// - NO usa Navigator directamente ni accede a repositorios/Firestore:
//   toda la navegación y el guardado se delegan vía onVolver/onFinalizar.
//
// NOTA DE DISEÑO: este archivo es solo presentación. La jerarquía visual es
// título → rubro (chip) → stepper → contenido → barra de acciones, sobre una
// única columna de superficies planas.
// ═════════════════════════════════════════════════════════════════════════

class ConfiguracionNegocioContent extends StatelessWidget {
  /// Identidad del usuario dueño del negocio. La necesita el paso Catálogo
  /// para las escrituras de categorías, que persisten por (uid, negocioId).
  final String uid;

  final String rubro;
  final VoidCallback onVolver;
  final VoidCallback onFinalizar;

  const ConfiguracionNegocioContent({
    super.key,
    required this.uid,
    required this.rubro,
    required this.onVolver,
    required this.onFinalizar,
  });

  static const _nombresPasos = ['Negocio', 'Catálogo', 'Logística', 'Pagos'];

  /// Ancho del botón primario: fijo en escritorio para que no se coma el
  /// ancho de la barra, y flexible cuando la barra es demasiado estrecha.
  static const _anchoPrimario = 200.0;

  /// Por debajo de este ancho los dos botones comparten el espacio disponible.
  static const _anchoBarraEstrecha = 420.0;

  /// A partir de este ancho el chip de rubro se alinea a la derecha del
  /// titular en vez de bajar a su propia línea.
  static const _anchoRubroEnLinea = 520.0;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 720;
        final paddingHorizontal = compacto ? 16.0 : 24.0;
        return Column(
          children: [
            // ── ENCABEZADO: volver + título + rubro + stepper ──────────────
            // Compacto a propósito: el título arranca casi en el borde
            // superior y el rubro vive en la MISMA fila, para que el primer
            // campo del formulario entre en pantalla sin desplazamiento.
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                paddingHorizontal,
                10,
                paddingHorizontal,
                12,
              ),
              decoration: BoxDecoration(
                color: AppColors.fondo,
                border: Border(
                  bottom: BorderSide(color: AppColors.bordeSutil),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, tituloConstraints) {
                      final encaberezado = _Encabezado(
                        rubro: rubro,
                        // En escritorio el rubro va a la derecha del titular;
                        // en columnas estrechas baja a una segunda línea para
                        // que ninguno de los dos se corte.
                        enLinea: tituloConstraints.maxWidth >= _anchoRubroEnLinea,
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _BotonVolver(
                            habilitado: !p.guardando,
                            onPressed: onVolver,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: encaberezado),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _BarraPasos(
                    pasoActual: p.pasoActual,
                    nombres: _nombresPasos,
                    onPasoClick: (i) {
                      if (i < p.pasoActual) p.irAPaso(i);
                    },
                  ),
                ],
              ),
            ),

            // ── CONTENIDO del paso actual ───────────────────────────────
            Expanded(
              child: IndexedStack(
                index: p.pasoActual,
                children: [
                  const PasoNegocio(),
                  PasoCatalogo(uid: uid),
                  const PasoLogistica(),
                  const PasoPagos(),
                ],
              ),
            ),

            // ── NAVEGACIÓN entre pasos ───────────────────────────────────
            // Vive en el flujo de la columna, nunca superpuesto: no puede
            // tapar el contenido del paso.
            _BarraAcciones(
              pasoActual: p.pasoActual,
              paddingHorizontal: paddingHorizontal,
              guardando: p.guardando,
              puedeAvanzar: p.puedeAvanzarActual,
              onCambiarRubro: onVolver,
              onAtras: p.atras,
              onSiguiente: p.siguiente,
              onFinalizar: onFinalizar,
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Encabezado
// ═════════════════════════════════════════════════════════════════════════

/// Volver al selector de rubro. Mismo callback que el botón de la barra
/// inferior: aquí solo cambia la presentación (botón cuadrado discreto).
class _BotonVolver extends StatelessWidget {
  final bool habilitado;
  final VoidCallback onPressed;

  const _BotonVolver({required this.habilitado, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cambiar rubro',
      child: Tooltip(
        message: 'Cambiar rubro',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: habilitado ? onPressed : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.bordeSutil),
              ),
              child: Icon(
                Icons.arrow_back,
                size: 18,
                color: habilitado ? AppColors.muted : AppColors.dim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Título principal + rubro como dato secundario.
///
/// El rubro ya no se concatena al título ("Configura tu Bodega"): es un chip
/// aparte pegado al titular, para que el título sea el foco visual y ocupe
/// una sola línea de alto.
class _Encabezado extends StatelessWidget {
  final String rubro;
  final bool enLinea;

  const _Encabezado({required this.rubro, required this.enLinea});

  @override
  Widget build(BuildContext context) {
    final titulo = Text(
      'Configura tu negocio',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.screenTitle.copyWith(
        fontSize: 26,
        height: 1.1,
        letterSpacing: -0.5,
        color: AppColors.texto,
      ),
    );
    final etiquetaRubro = Text(
      'Rubro:',
      style: AppTypography.screenSubtitle.copyWith(
        fontSize: 12.5,
        color: AppColors.muted,
      ),
    );
    final chip = _ChipRubro(texto: rubro);

    if (enLinea) {
      return Row(
        children: [
          Flexible(child: titulo),
          const SizedBox(width: 14),
          etiquetaRubro,
          const SizedBox(width: 7),
          Flexible(child: chip),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titulo,
        const SizedBox(height: 5),
        Row(children: [etiquetaRubro, const SizedBox(width: 7), Flexible(child: chip)]),
      ],
    );
  }
}

/// Chip discreto del rubro: solo un tono bajo de azul, sin robar protagonismo.
class _ChipRubro extends StatelessWidget {
  final String texto;

  const _ChipRubro({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.bordeMedio),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.blueLt,
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Stepper
// ═════════════════════════════════════════════════════════════════════════

/// Stepper del wizard: cuatro celdas iguales unidas por un riel.
///
/// Cada celda es un número + su etiqueta; el azul se reserva para el paso
/// activo. Los conectores se dibujan dentro de la celda, así que el riel
/// acompaña al número sin líneas superpuestas ni saltos de ancho.
class _BarraPasos extends StatelessWidget {
  final int pasoActual;
  final List<String> nombres;
  final void Function(int) onPasoClick;

  const _BarraPasos({
    required this.pasoActual,
    required this.nombres,
    required this.onPasoClick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < nombres.length; i++)
          Expanded(
            child: _CeldaPaso(
              numero: i + 1,
              nombre: nombres[i],
              activo: i == pasoActual,
              completado: i < pasoActual,
              conConectorIzquierdo: i > 0,
              conConectorDerecho: i < nombres.length - 1,
              onTap: () => onPasoClick(i),
            ),
          ),
      ],
    );
  }
}

class _CeldaPaso extends StatelessWidget {
  final int numero;
  final String nombre;
  final bool activo;
  final bool completado;
  final bool conConectorIzquierdo;
  final bool conConectorDerecho;
  final VoidCallback onTap;

  const _CeldaPaso({
    required this.numero,
    required this.nombre,
    required this.activo,
    required this.completado,
    required this.conConectorIzquierdo,
    required this.conConectorDerecho,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorRielIzquierdo = conConectorIzquierdo && completado
        ? AppColors.blueLt.withValues(alpha: 0.45)
        : AppColors.bordeSutil;
    final colorRielDerecho = conConectorDerecho && completado
        ? AppColors.blueLt.withValues(alpha: 0.45)
        : AppColors.bordeSutil;

    return Semantics(
      button: true,
      selected: activo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    child: conConectorIzquierdo
                        ? _Riel(color: colorRielIzquierdo)
                        : const SizedBox.shrink(),
                  ),
                  _InsigniaPaso(
                    numero: numero,
                    activo: activo,
                    completado: completado,
                  ),
                  Expanded(
                    child: conConectorDerecho
                        ? _Riel(color: colorRielDerecho)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.15,
                color: activo
                    ? AppColors.texto
                    : (completado ? AppColors.muted : AppColors.dim),
                fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Línea de 1 px del riel. Se encoge sola si el ancho no alcanza.
class _Riel extends StatelessWidget {
  final Color color;

  const _Riel({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: color);
  }
}

/// Círculo numerado del stepper. Relleno en el paso activo, contorno tenue en
/// el resto: el número siempre visible, para no depender solo del color.
class _InsigniaPaso extends StatelessWidget {
  final int numero;
  final bool activo;
  final bool completado;

  const _InsigniaPaso({
    required this.numero,
    required this.activo,
    required this.completado,
  });

  @override
  Widget build(BuildContext context) {
    final colorBorde = activo
        ? AppColors.blueLt
        : (completado ? AppColors.bordeMedio : AppColors.bordeSutil);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: activo ? AppColors.blueLt : AppColors.fondo,
        border: Border.all(color: colorBorde, width: 1.2),
      ),
      child: Text(
        '$numero',
        style: TextStyle(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w700,
          color: activo
              ? Colors.white
              : (completado ? AppColors.muted : AppColors.dim),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Barra de acciones
// ═════════════════════════════════════════════════════════════════════════

/// Barra inferior de navegación. Solo presentación: recibe los callbacks ya
/// resueltos por el provider y no cambia su orden ni su condición de habilitación.
class _BarraAcciones extends StatelessWidget {
  final int pasoActual;
  final double paddingHorizontal;
  final bool guardando;
  final bool puedeAvanzar;
  final VoidCallback onCambiarRubro;
  final VoidCallback onAtras;
  final VoidCallback onSiguiente;
  final VoidCallback onFinalizar;

  const _BarraAcciones({
    required this.pasoActual,
    required this.paddingHorizontal,
    required this.guardando,
    required this.puedeAvanzar,
    required this.onCambiarRubro,
    required this.onAtras,
    required this.onSiguiente,
    required this.onFinalizar,
  });

  bool get _esPrimerPaso => pasoActual == 0;

  bool get _esUltimoPaso =>
      pasoActual >= ConfiguracionNegocioProvider.totalPasos - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.fondo,
        border: Border(top: BorderSide(color: AppColors.bordeSutil)),
      ),
      padding: EdgeInsets.fromLTRB(paddingHorizontal, 11, paddingHorizontal, 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estrecho =
              constraints.maxWidth <
              ConfiguracionNegocioContent._anchoBarraEstrecha;
          if (estrecho) {
            return Row(
              children: [
                Expanded(child: _botonSecundario()),
                const SizedBox(width: 10),
                Expanded(child: _botonPrimario()),
              ],
            );
          }
          return Row(
            children: [
              Flexible(child: _botonSecundario()),
              const SizedBox(width: 12),
              SizedBox(
                width: ConfiguracionNegocioContent._anchoPrimario,
                height: 46,
                child: _botonPrimario(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Acción secundaria: outline, discreta, alineada a la izquierda.
  Widget _botonSecundario() {
    return OutlinedButton(
      onPressed: guardando ? null : (_esPrimerPaso ? onCambiarRubro : onAtras),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        foregroundColor: AppColors.texto,
        disabledForegroundColor: AppColors.dim,
        side: BorderSide(color: AppColors.bordeMedio),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: _ContenidoBoton(
        icono: Icons.arrow_back,
        texto: _esPrimerPaso ? 'Cambiar rubro' : 'Atrás',
        cargando: false,
        activo: !guardando,
      ),
    );
  }

  /// Acción primaria: azul, ancho fijo y jerarquía dominante.
  Widget _botonPrimario() {
    return ElevatedButton(
      onPressed: !puedeAvanzar || guardando
          ? null
          : () {
              if (!_esUltimoPaso) {
                onSiguiente();
                return;
              }
              onFinalizar();
            },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.dim,
        disabledForegroundColor: AppColors.muted,
      ),
      child: _ContenidoBoton(
        icono: _esUltimoPaso ? Icons.check_rounded : Icons.arrow_forward,
        texto: _esUltimoPaso ? 'Finalizar' : 'Siguiente',
        cargando: guardando,
        activo: puedeAvanzar && !guardando,
      ),
    );
  }
}

/// Fila etiqueta + icono de los botones de la barra.
///
/// La etiqueta va dentro de un [Flexible] con una sola línea: en barras
/// estrechas cede espacio con puntos suspensivos en lugar de desbordar la
/// fila o partir el texto en dos líneas.
class _ContenidoBoton extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool cargando;
  final bool activo;

  const _ContenidoBoton({
    required this.icono,
    required this.texto,
    required this.cargando,
    required this.activo,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: activo ? null : Theme.of(context).disabledColor,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cargando) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: activo ? Colors.white : Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(width: 10),
        ] else ...[
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: estilo,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icono, size: 16, color: activo ? null : estilo.color),
        ],
      ],
    );
  }
}
