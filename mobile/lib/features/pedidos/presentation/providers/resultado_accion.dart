enum TipoResultado { exito, aviso, error, ignorado }

/// Lo que la pantalla muestra después de una acción. [mensaje] es texto plano.
class ResultadoAccion {
  const ResultadoAccion(this.tipo, [this.mensaje = '']);

  const ResultadoAccion.ignorado() : this(TipoResultado.ignorado);

  final TipoResultado tipo;
  final String mensaje;

  bool get hizoAlgo => tipo != TipoResultado.ignorado;
  bool get fallo => tipo == TipoResultado.error;
}
