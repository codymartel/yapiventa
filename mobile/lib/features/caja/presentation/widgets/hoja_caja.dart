import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/tamanos_caja.dart';

/// Abre una hoja de Caja: desde abajo en celular y tableta, diálogo centrado
/// en PC. El contenido debe ser un [MarcoHojaCaja], que se encarga del
/// teclado, del poco alto y de deslizarse por dentro.
Future<T?> mostrarHojaCaja<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final forma = TamanosCaja.forma(MediaQuery.sizeOf(context).width);
  if (!forma.esFamiliaMovil) {
    return showDialog<T>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.superficie,
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TamanosCaja.anchoDialogo),
          child: builder(c),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// MarcoHojaCaja
// ═════════════════════════════════════════════════════════════════════════
// El marco de toda hoja de Caja (venta, gasto, ayuda). Reglas:
//
//   1. Nunca es más alta que el espacio libre: lo que no entra se DESLIZA por
//      dentro y el pie (el botón principal) queda fijo. Nada se encoge.
//   2. Con el teclado abierto la hoja sube con él; el campo que se escribe
//      queda a la vista (el deslizable lo lleva solo).
//   3. Con poco alto (celular de lado) pasa a dos columnas: a la izquierda lo
//      que se escribe y a la derecha lo que se elige y el pie.
//   4. Con poco alto Y teclado muestra solo lo que se escribe, con el pie al
//      costado.
//
// [escribir] son los campos de texto, [elegir] los chips y opciones, [pie] el
// botón principal con su aviso. En vertical se ven en ese orden, salvo
// [escribirAlFinal], que va después de [elegir] (por ejemplo, la nota).
// ═════════════════════════════════════════════════════════════════════════
class MarcoHojaCaja extends StatelessWidget {
  const MarcoHojaCaja({
    super.key,
    required this.titulo,
    required this.onCerrar,
    this.textoCerrar = 'Cancelar',
    this.escribir = const [],
    this.elegir = const [],
    this.escribirAlFinal = const [],
    this.pie,
    this.pieApretado,
  });

  final String titulo;
  final VoidCallback onCerrar;
  final String textoCerrar;
  final List<Widget> escribir;
  final List<Widget> elegir;
  final List<Widget> escribirAlFinal;
  final Widget? pie;

  /// El pie cuando queda muy poco alto (de lado y con teclado): una versión
  /// de una sola línea. Si no se da, se usa [pie].
  final Widget? pieApretado;

  static const double _margen = 16;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final teclado = mq.viewInsets.bottom;
    final forma = TamanosCaja.forma(mq.size.width);
    final enDialogo = !forma.esFamiliaMovil;
    final libre =
        mq.size.height - teclado - mq.padding.top - (enDialogo ? 32 : 0);
    final bajo = !enDialogo && TamanosCaja.esBajo(mq.size.height);

    final Widget cuerpo;
    if (bajo && libre < TamanosCaja.altoMinimoHoja) {
      cuerpo = _soloEscribir();
    } else if (bajo) {
      cuerpo = _dosColumnas();
    } else {
      cuerpo = _vertical(conAgarre: !enDialogo);
    }

    // Sin animación propia: el teclado ya sube y baja de a poco, y animar
    // aquí dejaría por un instante un diseño que no corresponde al alto real.
    return Padding(
      // En diálogo, `Dialog` ya se aparta del teclado por su cuenta.
      padding: EdgeInsets.only(bottom: enDialogo ? 0 : teclado),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: libre < 120 ? 120 : libre),
        child: bajo ? SizedBox(height: libre, child: cuerpo) : cuerpo,
      ),
    );
  }

  Widget _cabecera({bool compacta = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_margen, compacta ? 0 : 4, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: AppColors.azulTexto,
            ),
            onPressed: onCerrar,
            child: Text(textoCerrar),
          ),
        ],
      ),
    );
  }

  Widget _deslizable(List<Widget> hijos) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(_margen, 8, _margen, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < hijos.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            hijos[i],
          ],
        ],
      ),
    );
  }

  Widget _pieFijo({double arriba = 8}) {
    final p = pie;
    if (p == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(_margen, arriba, _margen, 12),
      child: p,
    );
  }

  Widget _vertical({required bool conAgarre}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (conAgarre)
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppColors.dim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          )
        else
          const SizedBox(height: 8),
        _cabecera(),
        Flexible(
          child: _deslizable([...escribir, ...elegir, ...escribirAlFinal]),
        ),
        _pieFijo(),
      ],
    );
  }

  Widget _dosColumnas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(compacta: true),
        const Divider(height: 1, color: AppColors.dim),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _deslizable([...escribir, ...escribirAlFinal])),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _deslizable(elegir)),
                    _pieFijo(arriba: 0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _soloEscribir() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(compacta: true),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _deslizable([...escribir, ...escribirAlFinal])),
              if (pie != null)
                SizedBox(
                  width: 260,
                  // Por si aun así no entra: se desliza, nunca se desborda.
                  child: SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(0, 0, _margen, 8),
                    child: pieApretado ?? pie,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
