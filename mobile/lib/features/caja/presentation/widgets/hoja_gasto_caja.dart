import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/textos_dia_caja.dart';
import '../../application/services/textos_gastos_caja.dart';
import '../../domain/models/gasto_caja.dart';
import '../providers/gasto_caja_provider.dart';
import 'botones_caja.dart';
import 'chip_caja.dart';
import 'hoja_caja.dart';
import 'piezas_caja.dart';

/// Abre el gasto rápido («S/ 10 de comida»): hoja desde abajo en celular y
/// tableta, diálogo en PC. Devuelve el resultado si se guardó (para el aviso
/// con «Anular»), o null si se canceló. Lo escrito se conserva en el provider
/// si la hoja se cierra o falla la conexión.
///
/// Con un provider que está corrigiendo, la misma hoja llega llena, dice
/// cómo era antes y trae «Anular este gasto» (con un segundo toque para
/// confirmar). Devuelve el resultado de corregir o de anular.
Future<ResultadoGastoCaja?> mostrarHojaGasto(
  BuildContext context, {
  required GastoCajaProvider provider,
}) {
  return mostrarHojaCaja<ResultadoGastoCaja>(
    context,
    builder: (c) => _ContenidoGasto(provider: provider),
  );
}

class _ContenidoGasto extends StatefulWidget {
  const _ContenidoGasto({required this.provider});

  final GastoCajaProvider provider;

  @override
  State<_ContenidoGasto> createState() => _ContenidoGastoState();
}

class _ContenidoGastoState extends State<_ContenidoGasto> {
  late final _monto = TextEditingController(text: _p.montoTexto);
  late final _nota = TextEditingController(text: _p.nota);
  String? _error;

  /// «Anular este gasto» pide un segundo toque antes de anular.
  bool _confirmarAnular = false;
  bool _anulando = false;

  GastoCajaProvider get _p => widget.provider;

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _error = null);
    final r = await _p.guardar();
    if (!mounted) return;
    // «Ya estaba anulado» también cierra: la lista lo tacha y lo explica.
    if (r.ok || r.viejoAnulado) {
      Navigator.of(context).pop(r);
    } else if (r.mensaje.isNotEmpty) {
      setState(() => _error = r.mensaje);
    }
  }

  Future<void> _anular() async {
    if (!_confirmarAnular) {
      setState(() => _confirmarAnular = true);
      return;
    }
    setState(() {
      _anulando = true;
      _error = null;
    });
    final r = await _p.anular(_p.original!.id);
    if (!mounted) return;
    if (r.ok) {
      Navigator.of(context).pop(r);
    } else {
      setState(() {
        _anulando = false;
        _error = r.mensaje;
      });
    }
  }

  String _textoBoton(int? monto) {
    if (_p.guardando) return 'Guardando…';
    final base = _p.corrigiendo ? 'Guardar corrección' : 'Guardar gasto';
    if (monto == null || monto <= 0) return base;
    return '$base · ${TextosDiaCaja.plata(monto)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _p,
      builder: (context, _) {
        final monto = _p.montoCentavos;
        final falta = _error ?? _p.motivoNoGuardar;
        final original = _p.original;
        return MarcoHojaCaja(
          titulo: original == null ? 'Gasto' : 'Corregir gasto',
          onCerrar: () => Navigator.of(context).pop(),
          escribir: [
            if (original != null) _Antes(original: original, nuevo: monto),
            _CampoMonto(
              controller: _monto,
              onChanged: _p.escribirMonto,
              etiqueta: original == null
                  ? '¿Cuánto se gastó?'
                  : '¿Cuánto fue de verdad?',
            ),
          ],
          elegir: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const TituloSeccionCaja('¿En qué?'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in MotivoGasto.values)
                      ChipCaja(
                        etiqueta: m.etiqueta,
                        activo: _p.motivo == m,
                        altoMinimo: 44,
                        onTap: () => _p.elegirMotivo(m),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const TituloSeccionCaja('¿De dónde salió?'),
                const SizedBox(height: 6),
                if (_p.opcionesPago.isEmpty)
                  const AvisoCaja(
                    'Aún no tienes formas de pago activas. Actívalas en '
                    'Configuración para anotar gastos.',
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in _p.opcionesPago)
                        ChipCaja(
                          etiqueta: o.etiqueta,
                          activo: _p.pago?.id == o.id,
                          altoMinimo: 44,
                          onTap: () => _p.elegirPago(o),
                        ),
                    ],
                  ),
              ],
            ),
          ],
          escribirAlFinal: [
            CampoCaja(
              etiqueta: 'Nota (opcional)',
              controller: _nota,
              onChanged: _p.escribirNota,
              ejemplo: 'Por ejemplo: almuerzo',
              maximo: 120,
              accion: TextInputAction.done,
            ),
          ],
          pie: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonPrincipalCaja(
                texto: _textoBoton(monto),
                onTap: _p.puedeGuardar && !_anulando ? _guardar : null,
              ),
              if (falta != null) ...[
                const SizedBox(height: 6),
                Text(
                  falta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    // Al corregir, lo que falta es una indicación (gris),
                    // no un problema: el gasto llega lleno a propósito.
                    color: _error != null
                        ? AppColors.error
                        : original != null
                        ? AppColors.muted
                        : AppColors.aviso,
                    fontSize: 12,
                  ),
                ),
              ],
              if (original != null)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: _p.guardando || _anulando ? null : _anular,
                  child: Text(
                    _anulando
                        ? 'Anulando…'
                        : _confirmarAnular
                        ? 'Toca otra vez para anularlo'
                        : 'Anular este gasto (sin poner otro)',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Cómo estaba el gasto y qué va a pasar, en palabras simples:
///
///   Antes: S/ 100,00 · Mercadería · 9:40
///   El de S/ 100,00 queda tachado y se guarda el de S/ 10,00.
class _Antes extends StatelessWidget {
  const _Antes({required this.original, required this.nuevo});

  final GastoCaja original;
  final int? nuevo;

  @override
  Widget build(BuildContext context) {
    final viejo = TextosDiaCaja.plata(original.montoCentavos);
    final n = nuevo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TextosGastosCaja.antes(original, viejo),
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          // Con el mismo monto (o sin monto aún) se dice «el nuevo»: «se
          // guarda el de S/ 36,00» repetido confunde.
          n != null && n > 0 && n != original.montoCentavos
              ? 'El de $viejo queda tachado y se guarda el de '
                    '${TextosDiaCaja.plata(n)}. Los números del día se '
                    'arreglan solos.'
              : 'El de $viejo queda tachado y se guarda el nuevo. Los '
                    'números del día se arreglan solos.',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}

/// El monto, grande y con teclado de números. Solo acepta cifras y UNA coma
/// o punto con hasta 2 decimales (el dinero se guarda en céntimos enteros).
class _CampoMonto extends StatelessWidget {
  const _CampoMonto({
    required this.controller,
    required this.onChanged,
    required this.etiqueta,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: ancho),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d{0,6}([.,]\d{0,2})?'),
            ),
          ],
          textAlign: TextAlign.center,
          scrollPadding: const EdgeInsets.only(bottom: 96),
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            prefixText: 'S/ ',
            prefixStyle: const TextStyle(color: AppColors.muted, fontSize: 20),
            hintText: '0',
            hintStyle: const TextStyle(color: AppColors.hint, fontSize: 34),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: borde(AppColors.hint, 1),
            focusedBorder: borde(AppColors.blueLt, 2),
          ),
        ),
      ],
    );
  }
}
