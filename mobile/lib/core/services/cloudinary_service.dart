import 'dart:convert';
import 'package:http/http.dart' as http;
import 'subidor_de_imagenes.dart';

// ═════════════════════════════════════════════════════════════════════════
// CloudinaryService
// ═════════════════════════════════════════════════════════════════════════
// Implementación de SubidorDeImagenes usando la API REST de Cloudinary
// (unsigned upload — sin backend propio, igual que tu Kotlin con
// MediaManager). Guarda public_id junto a la URL, preparado para poder
// borrar más adelante o migrar a otro proveedor sin perder datos.
//
// Cloud name y preset: dym0jam5e / webb_enprendimiento (cuenta ya creada).
// ═════════════════════════════════════════════════════════════════════════

class CloudinaryService implements SubidorDeImagenes {
  static const _cloudName = 'dym0jam5e';
  static const _uploadPreset = 'webb_enprendimiento';

  @override
  Future<ResultadoSubida> subir({
    required List<int> bytes,
    required String carpeta,
    required String nombreArchivo,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = carpeta
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: nombreArchivo));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Error al subir a Cloudinary: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ResultadoSubida(
      url: data['secure_url'] as String,
      identificador: data['public_id'] as String,
    );
  }

  @override
  Future<void> borrar(String identificador) {
    // Borrar en Cloudinary requiere firma autenticada (no disponible
    // con unsigned preset desde el cliente) — pendiente, ver informe:
    // requeriría una Cloud Function u otro backend.
    throw UnimplementedError(
      'Borrado de Cloudinary pendiente — requiere firma autenticada (backend).',
    );
  }
}