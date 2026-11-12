import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/textos_dia_caja.dart';
import '../../domain/models/dia_caja.dart';
import '../providers/dia_caja_provider.dart';

/// Cómo se dibujan los números del día.
enum EstiloDiaCaja {
  /// Celular y tableta: 3 tarjetas y, debajo, local y tienda web.
  tarjetas,

  /// Poco alto (celular de lado, laptop bajita): todo en una fila delgada.
  fila,

  /// PC: 6 tarjetas (separa tienda web y local, y agrega «Queda del día»).
  tablero,
}

/// Los números del día en vivo: ventas, efectivo en caja y gastos, con lo
/// vendido separado en local y tienda web. Lee el [DiaCajaProvider] (UN
/// documento). «Gastos» se puede tocar para ver y corregir los de hoy. Si falla la conexión lo dice con texto y ofrece «Reintentar»;
/// los números que quedan pueden estar viejos.
class BarraDiaCaja extends StatelessWidget {
  const BarraDiaCaja({
    super.key,
    required this.provider,
    this.estilo = EstiloDiaCaja.tarjetas,
    this.onVerGastos,
  });

  final DiaCajaProvider provider;
  final EstiloDiaCaja estilo;

  /// Con valor, «Gastos» se puede tocar: abre «Gastos de hoy» (para ver y
  /// corregir).
  final VoidCallback? onVerGastos;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final dia = provider.dia;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.error && estilo != EstiloDiaCaja.fila) ...[
              _AvisoSinConexion(onReintentar: provider.reintentar),
              const SizedBox(height: 8),
            ],
            switch (estilo) {
              EstiloDiaCaja.tarjetas => _Tarjetas(
                datos: _datos(dia, todos: false, onVerGastos: onVerGastos),
                dia: dia,
              ),
              EstiloDiaCaja.fila => _Fila(
                datos: [
                  ..._datos(dia, todos: true, onVerGastos: onVerGastos),
                  if (dia.porCobrarCentavos > 0)
                    _Dato(
                      'Por cobrar',
                      dia.porCobrarCentavos,
                      'entregado sin cobrar',
                      corto: 'Por cobrar',
                    ),
                ],
                onReintentar: provider.error ? provider.reintentar : null,
              ),
              EstiloDiaCaja.tablero => _Tablero(
                datos: _datos(dia, todos: true, onVerGastos: onVerGastos),
              ),
            },
          ],
        );
      },
    );
  }
}

class _Dato {
  const _Dato(
    this.titulo,
    this.centavos,
    this.nota, {
    this.corto = '',
    this.onTap,
  });

  final String titulo;
  final int centavos;
  final String nota;

  /// El título de la fila delgada («Hoy», «Web»…).
  final String corto;

  /// Con valor, el dato se puede tocar (hoy solo «Gastos»).
  final VoidCallback? onTap;
}

List<_Dato> _datos(
  DiaCaja dia, {
  required bool todos,
  VoidCallback? onVerGastos,
}) {
  final ventas = _Dato(
    'Ventas de hoy',
    dia.ventasCentavos,
    todos
        ? TextosDiaCaja.notaVentas(dia)
        : TextosDiaCaja.cuantasVentas(dia.ventas.entregados),
    corto: 'Hoy',
  );
  final efectivo = _Dato(
    'Efectivo en caja',
    dia.efectivoCentavos,
    TextosDiaCaja.notaEfectivo(dia),
    corto: 'Efectivo',
  );
  final gastos = _Dato(
    'Gastos',
    dia.gastosCentavos,
    TextosDiaCaja.cuantosGastos(dia.gastos.cantidad),
    corto: 'Gastos',
    onTap: onVerGastos,
  );
  if (!todos) return [ventas, efectivo, gastos];
  return [
    ventas,
    _Dato(
      'Tienda web',
      TextosDiaCaja.webCentavos(dia),
      'entregado',
      corto: 'Web',
    ),
    _Dato(
      'Local',
      TextosDiaCaja.localCentavos(dia),
      'en mostrador',
      corto: 'Local',
    ),
    efectivo,
    gastos,
    _Dato(
      'Queda del día',
      dia.quedaCentavos,
      'ventas − gastos',
      corto: 'Queda',
    ),
  ];
}

class _Tarjetas extends StatelessWidget {
  const _Tarjetas({required this.datos, required this.dia});

  final List<_Dato> datos;
  final DiaCaja dia;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < datos.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _Tarjeta(dato: datos[i])),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _LocalYWeb(dia: dia),
      ],
    );
  }
}

class _Tablero extends StatelessWidget {
  const _Tablero({required this.datos});

  final List<_Dato> datos;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < datos.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _Tarjeta(dato: datos[i])),
          ],
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.dato});

  final _Dato dato;

  @override
  Widget build(BuildContext context) {
    final negativo = dato.centavos < 0;
    final onTap = dato.onTap;
    final radio = BorderRadius.circular(12);
    return Semantics(
      label:
          '${dato.titulo}: ${TextosDiaCaja.plata(dato.centavos)}, '
          '${dato.nota}${onTap == null ? '' : '. Toca para ver y corregir'}',
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(color: AppColors.bordeMedio),
        ),
        child: InkWell(
          borderRadius: radio,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: _contenido(negativo, conFlecha: onTap != null),
          ),
        ),
      ),
    );
  }

  Widget _contenido(bool negativo, {required bool conFlecha}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dato.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
            if (conFlecha)
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.azulTexto,
              ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            TextosDiaCaja.plata(dato.centavos),
            style: TextStyle(
              color: negativo ? AppColors.aviso : AppColors.texto,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          dato.nota,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.hint, fontSize: 11),
        ),
      ],
    );
  }
}

class _LocalYWeb extends StatelessWidget {
  const _LocalYWeb({required this.dia});

  final DiaCaja dia;

  @override
  Widget build(BuildContext context) {
    const etiqueta = TextStyle(color: AppColors.muted, fontSize: 12);
    const valor = TextStyle(
      color: AppColors.texto,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        const Text('Local', style: etiqueta),
        Text(
          TextosDiaCaja.plata(TextosDiaCaja.localCentavos(dia)),
          style: valor,
        ),
        const Text('·', style: etiqueta),
        const Text('Tienda web', style: etiqueta),
        Text(TextosDiaCaja.plata(TextosDiaCaja.webCentavos(dia)), style: valor),
        // Entregado sin cobrar: no está en la caja (solo si hay algo).
        if (dia.porCobrarCentavos > 0) ...[
          const Text('·', style: etiqueta),
          const Text('Por cobrar', style: etiqueta),
          Text(
            TextosDiaCaja.plata(dia.porCobrarCentavos),
            style: valor.copyWith(color: AppColors.aviso),
          ),
        ],
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.datos, this.onReintentar});

  final List<_Dato> datos;

  /// Con valor: no hay conexión. Se dice con texto en la misma fila y al
  /// tocarlo se vuelve a intentar.
  final VoidCallback? onReintentar;

  /// Un dato que se puede tocar («Gastos ›»): la zona de toque mide 44 px de
  /// alto aunque el chip se vea delgado.
  Widget _tocable(_Dato dato, Widget chip) {
    final onTap = dato.onTap;
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: '${dato.titulo}. Toca para ver y corregir',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(widthFactor: 1, child: chip),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (onReintentar != null) ...[
            ActionChip(
              avatar: const Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: AppColors.aviso,
              ),
              label: const Text('Sin conexión · Reintentar'),
              labelStyle: const TextStyle(color: AppColors.aviso, fontSize: 12),
              backgroundColor: AppColors.card,
              side: const BorderSide(color: AppColors.aviso),
              onPressed: onReintentar,
            ),
            const SizedBox(width: 6),
          ],
          for (var i = 0; i < datos.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _tocable(
              datos[i],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bordeMedio),
                ),
                child: Text.rich(
                  TextSpan(
                    text: '${datos[i].corto} ',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: TextosDiaCaja.numero(datos[i].centavos),
                        style: TextStyle(
                          color: datos[i].centavos < 0
                              ? AppColors.aviso
                              : AppColors.texto,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (datos[i].onTap != null)
                        const TextSpan(
                          text: ' ›',
                          style: TextStyle(color: AppColors.azulTexto),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.aviso.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.aviso.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AppColors.aviso,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No se pudo actualizar el día. Los números pueden estar viejos.',
              style: TextStyle(color: AppColors.aviso, fontSize: 13),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: AppColors.aviso,
            ),
            onPressed: onReintentar,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
