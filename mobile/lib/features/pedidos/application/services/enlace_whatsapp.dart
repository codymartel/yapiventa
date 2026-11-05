import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';

// ═════════════════════════════════════════════════════════════════════════
// EnlaceWhatsapp
// ═════════════════════════════════════════════════════════════════════════
// Arma el enlace https://wa.me/<número> para escribirle al cliente.
//
// SEGURIDAD: el teléfono viene de una tienda pública, así que se deja SOLO
// con dígitos (nada de texto libre dentro de la URL) y el mensaje opcional
// se codifica con `Uri` (nunca se concatena a mano).
//
// Si el número tiene los dígitos de un celular del país («987 654 321» en
// Perú), se le agrega el prefijo; si ya trae más, se asume que ya lo incluye.
// ═════════════════════════════════════════════════════════════════════════
abstract final class EnlaceWhatsapp {
  static const int _minimoDigitos = 7;

  static PaisTelefono get _peru =>
      paisesLatam.firstWhere((p) => p.nombre == 'Perú');

  /// Solo los dígitos del teléfono, sin espacios, guiones ni «+».
  static String soloDigitos(String telefono) =>
      telefono.replaceAll(RegExp(r'[^0-9]'), '');

  /// null si el teléfono no sirve (vacío o demasiado corto).
  static Uri? construir(
    String telefono, {
    PaisTelefono? pais,
    String mensaje = '',
  }) {
    final digitos = soloDigitos(telefono);
    if (digitos.length < _minimoDigitos) return null;
    final paisUsado = pais ?? _peru;
    final prefijo = soloDigitos(paisUsado.prefijo);
    final completo = digitos.length == paisUsado.digitosEsperados
        ? '$prefijo$digitos'
        : digitos;
    return Uri.https(
      'wa.me',
      '/$completo',
      mensaje.trim().isEmpty ? null : {'text': mensaje.trim()},
    );
  }
}
