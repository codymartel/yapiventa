import 'dart:math';

/// 20 caracteres al azar: el id de una venta o de un gasto desde que se
/// empieza a armar. Reintentar con el mismo id no cobra ni gasta dos veces.
String idAleatorioCaja() {
  const letras =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final azar = Random.secure();
  return List.generate(20, (_) => letras[azar.nextInt(letras.length)]).join();
}
