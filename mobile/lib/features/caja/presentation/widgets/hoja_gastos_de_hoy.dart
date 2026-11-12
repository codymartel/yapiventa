import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/textos_dia_caja.dart';
import '../../application/services/textos_gastos_caja.dart';
import '../../domain/models/gasto_caja.dart';
import '../../domain/models/opciones_caja.dart';
import '../providers/gastos_de_hoy_provider.dart';
import 'botones_caja.dart';
import 'hoja_caja.dart';

/// Abre «Gastos de hoy»: hoja desde abajo en celular y tableta, diálogo en
/// PC. Cada gasto trae «Corregir» ([onCorregir] abre el formulario lleno);
/// los anulados se ven tachados y sin botón. La lista ya debe estar
/// cargando ([GastosDeHoyProvider.cargar]).
Future<void> mostrarHojaGastosDeHoy(
  BuildContext context, {
  required GastosDeHoyProvider provider,
  required List<OpcionPagoCaja> opcionesPago,
  required ValueChanged<GastoCaja> onCorregir,
}) {
  return mostrarHojaCaja<void>(
    context,
    builder: (c) => _ContenidoGastosDeHoy(
      provider: provider,
      opcionesPago: opcionesPago,
      onCorregir: onCorregir,
    ),
  );
}

class _ContenidoGastosDeHoy extends StatelessWidget {
  const _ContenidoGastosDeHoy({
    required this.provider,
    required this.opcionesPago,
    required this.onCorregir,
  });

  final GastosDeHoyProvider provider;
  final List<OpcionPagoCaja> opcionesPago;
  final ValueChanged<GastoCaja> onCorregir;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final enDialogo = esHojaEnDialogo(context);
    final libre = mq.size.height - mq.padding.top - (enDialogo ? 64 : 24);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: libre < 160 ? 160 : libre),
      child: ListenableBuilder(
        listenable: provider,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!enDialogo)
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
              ),
            _Cabecera(onCerrar: () => Navigator.of(context).pop()),
            Flexible(child: _cuerpo()),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (provider.cargando && provider.gastos.isEmpty) {
      return const _Mensaje(icono: null, texto: 'Buscando los gastos de hoy…');
    }
    if (provider.error) {
      return _Mensaje(
        icono: Icons.cloud_off_outlined,
        texto: 'No se pudieron traer los gastos. Revisa tu conexión.',
        accion: BotonSecundarioCaja(
          texto: 'Reintentar',
          onTap: provider.cargar,
        ),
      );
    }
    final gastos = provider.gastos;
    if (gastos.isEmpty) {
      return const _Mensaje(
        icono: Icons.receipt_long_outlined,
        texto: 'Hoy no anotaste gastos.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
      itemCount: gastos.length + 1,
      separatorBuilder: (_, i) => i == 0
          ? const SizedBox.shrink()
          : const Divider(height: 1, color: AppColors.dim),
      itemBuilder: (context, i) {
        if (i == 0) return _Encabezado(provider: provider);
        final g = gastos[i - 1];
        return _FilaGasto(
          gasto: g,
          detalle: TextosGastosCaja.detalle(g, opcionesPago),
          onCorregir: g.anulado ? null : () => onCorregir(g),
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.onCerrar});

  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Gastos de hoy',
              style: TextStyle(
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
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

/// La primera fila de la lista: qué se puede hacer aquí y, si acaba de
/// pasar, lo último que se corrigió o anuló (en verde, con ícono).
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.provider});

  final GastosDeHoyProvider provider;

  @override
  Widget build(BuildContext context) {
    final cambio = provider.ultimoCambio;
    final color = provider.ultimoOk ? AppColors.ok : AppColors.aviso;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '¿Anotaste algo mal? Toca «Corregir».',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (provider.hayMas) ...[
            const SizedBox(height: 4),
            const Text(
              'Se muestran hasta 20 gastos de hoy.',
              style: TextStyle(color: AppColors.hint, fontSize: 12),
            ),
          ],
          if (cambio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  provider.ultimoOk
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cambio,
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Un gasto: motivo y monto grandes, debajo la hora y de dónde salió. Un
/// anulado se ve tachado, más tenue y sin «Corregir».
class _FilaGasto extends StatelessWidget {
  const _FilaGasto({
    required this.gasto,
    required this.detalle,
    required this.onCorregir,
  });

  final GastoCaja gasto;
  final String detalle;
  final VoidCallback? onCorregir;

  @override
  Widget build(BuildContext context) {
    final anulado = gasto.anulado;
    final principal = TextStyle(
      color: anulado ? AppColors.hint : AppColors.texto,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      decoration: anulado ? TextDecoration.lineThrough : null,
      decorationColor: AppColors.hint,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final plata = TextosDiaCaja.plata(gasto.montoCentavos);
    return Semantics(
      label:
          '${gasto.motivo.etiqueta}, $plata, $detalle'
          '${anulado ? '' : '. Toca Corregir para cambiarlo'}',
      excludeSemantics: anulado,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gasto.motivo.etiqueta, style: principal),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(plata, style: principal),
            const SizedBox(width: 4),
            SizedBox(
              width: 96,
              child: onCorregir == null
                  ? const SizedBox(height: 44)
                  : TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        foregroundColor: AppColors.azulTexto,
                      ),
                      onPressed: onCorregir,
                      child: const Text('Corregir'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto, this.accion});

  final IconData? icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono == null)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icono, size: 28, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          if (accion != null) ...[const SizedBox(height: 12), accion!],
        ],
      ),
    );
  }
}
