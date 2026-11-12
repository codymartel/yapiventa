import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/textos_dia_caja.dart';
import '../../domain/models/dia_caja.dart';
import '../../domain/models/gasto_caja.dart';
import '../providers/dia_caja_provider.dart';

/// Caja en la TV (1 600 px o más): solo se MIRA el día, con letra grande para
/// verlo de lejos. Aquí no se cobra ni se anotan gastos (igual que la TV de
/// Pedidos): eso se hace en el celular, la tableta o la PC.
class CajaVistaTv extends StatelessWidget {
  const CajaVistaTv({super.key, required this.provider});

  final DiaCajaProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final dia = provider.dia;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Caja · hoy',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    provider.error ? '● Sin conexión' : '● En vivo',
                    style: TextStyle(
                      color: provider.error ? AppColors.aviso : AppColors.ok,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Fila([
                _Cifra(
                  'Ventas de hoy',
                  dia.ventasCentavos,
                  TextosDiaCaja.cuantasVentas(dia.ventas.entregados),
                ),
                _Cifra(
                  'Efectivo en caja',
                  dia.efectivoCentavos,
                  TextosDiaCaja.notaEfectivo(dia),
                ),
                _Cifra(
                  'Gastos',
                  dia.gastosCentavos,
                  TextosDiaCaja.cuantosGastos(dia.gastos.cantidad),
                ),
                _Cifra('Queda del día', dia.quedaCentavos, 'ventas − gastos'),
              ]),
              const SizedBox(height: 16),
              _Fila([
                _Cifra(
                  'Tienda web',
                  TextosDiaCaja.webCentavos(dia),
                  'entregado',
                ),
                _Cifra(
                  'Local',
                  TextosDiaCaja.localCentavos(dia),
                  'en mostrador',
                ),
                _GastosPorMotivo(dia: dia),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.hijos);

  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < hijos.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              flex: hijos[i] is _GastosPorMotivo ? 2 : 1,
              child: hijos[i],
            ),
          ],
        ],
      ),
    );
  }
}

BoxDecoration get _caja => BoxDecoration(
  color: AppColors.card,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.bordeMedio),
);

class _Cifra extends StatelessWidget {
  const _Cifra(this.titulo, this.centavos, this.nota);

  final String titulo;
  final int centavos;
  final String nota;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: _caja,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              TextosDiaCaja.plata(centavos),
              style: TextStyle(
                color: centavos < 0 ? AppColors.aviso : AppColors.texto,
                fontSize: 44,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            nota,
            style: const TextStyle(color: AppColors.hint, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _GastosPorMotivo extends StatelessWidget {
  const _GastosPorMotivo({required this.dia});

  final DiaCaja dia;

  @override
  Widget build(BuildContext context) {
    final motivos = dia.gastos.porMotivo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: _caja,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gastos de hoy por motivo',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (motivos.isEmpty)
            const Text(
              'Hoy no hay gastos',
              style: TextStyle(color: AppColors.texto, fontSize: 24),
            )
          else
            for (final m in motivos.take(4))
              Text(
                '${MotivoGasto.desdeId(m.key).etiqueta} '
                '${TextosDiaCaja.plata(m.value)}',
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
          const SizedBox(height: 8),
          const Text(
            'Para cobrar o anotar un gasto usa el celular, la tableta o la PC',
            style: TextStyle(color: AppColors.hint, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
