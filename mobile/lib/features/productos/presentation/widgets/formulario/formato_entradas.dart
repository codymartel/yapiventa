import 'package:flutter/services.dart';

/// Formatters de las entradas numéricas del formulario.
/// - precio: como máximo 2 decimales.
/// - cantidad: como máximo 3 decimales (la unidad base de peso/volumen
///   admite ese detalle; el truncamiento lo decide medida_entrada).
/// - entero: solo dígitos.
class FormatoPrecio extends TextInputFormatter {
  const FormatoPrecio();

  static final _patron = RegExp(r'^\d*(?:[.,]\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || _patron.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

class FormatoCantidad extends TextInputFormatter {
  const FormatoCantidad();

  static final _patron = RegExp(r'^\d*(?:[.,]\d{0,3})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || _patron.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

class FormatoEntero extends TextInputFormatter {
  const FormatoEntero();

  static final _patron = RegExp(r'^\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _patron.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
