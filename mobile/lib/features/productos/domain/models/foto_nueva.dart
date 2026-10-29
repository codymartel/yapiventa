import 'dart:typed_data';

/// Una foto elegida en el formulario que todavía no se subió.
class FotoNueva {
  const FotoNueva({required this.bytes, required this.nombreArchivo});

  final Uint8List bytes;
  final String nombreArchivo;
}
