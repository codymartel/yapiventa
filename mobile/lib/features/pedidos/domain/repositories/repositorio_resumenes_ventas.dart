import '../models/resumen_ventas_dia.dart';

/// Lectura de los resúmenes diarios de ventas, para los informes. La
/// implementación vive en `data/`. (Escribir ventas es otro contrato:
/// `RepositorioVentasMostrador`.)
abstract class RepositorioResumenesVentas {
  /// Los resúmenes diarios de [desde] a [hasta] (AAAA-MM-DD, ambos incluidos)
  /// con UNA consulta por rango. Un día sin ventas no tiene documento, así que
  /// no viene en la lista: se leen como máximo tantos documentos como días con
  /// ventas (tope 31). Lanza [ArgumentError] si el rango es inválido o pasa de
  /// 31 días.
  Future<List<ResumenVentasDia>> obtenerResumenes(
    String negocioId,
    String desde,
    String hasta,
  );
}
