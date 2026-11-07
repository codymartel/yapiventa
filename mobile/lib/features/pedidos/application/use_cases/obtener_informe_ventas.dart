import '../../domain/models/informe_ventas.dart';
import '../../domain/repositories/repositorio_resumenes_ventas.dart';
import '../services/calculo_informe_ventas.dart';
import '../services/periodo_informe.dart';

/// Arma el informe de ventas de un periodo (hoy, semana, mes o un día) y, si se
/// pide, el del periodo anterior para comparar. Cada periodo es UNA consulta
/// por rango de resúmenes diarios: hoy 1 documento, semana hasta 7, mes hasta
/// 31 (el doble al comparar). No lee pedidos.
class ObtenerInformeVentas {
  const ObtenerInformeVentas(this._repositorio);

  final RepositorioResumenesVentas _repositorio;

  Future<InformeComparado> call({
    required String negocioId,
    required TipoPeriodo tipo,
    required DateTime ahora,
    String? dia,
    bool comparar = true,
  }) async {
    final periodo = PeriodoInforme.de(tipo, ahora, dia: dia);
    // Las dos consultas son independientes: van a la vez.
    final pedidoActual = _informe(negocioId, periodo.desde, periodo.hasta);
    final pedidoAnterior = comparar
        ? _informe(negocioId, periodo.anteriorDesde, periodo.anteriorHasta)
        : null;
    return InformeComparado(
      actual: await pedidoActual,
      anterior: pedidoAnterior == null ? null : await pedidoAnterior,
    );
  }

  Future<InformeVentas> _informe(
    String negocioId,
    String desde,
    String hasta,
  ) async {
    final resumenes = await _repositorio.obtenerResumenes(
      negocioId,
      desde,
      hasta,
    );
    return CalculoInformeVentas.armar(desde, hasta, resumenes);
  }
}
