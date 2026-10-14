/// `users/{uid}` referencia un `negocioId` cuyo documento `negocios/{id}` no
/// existe.
///
/// Es un estado inconsistente, no un problema de conexión: el perfil quedó
/// apuntando a un negocio que ya no está. Antes de existir esta excepción,
/// esa lectura terminaba en el `catch` genérico de la capa de presentación y
/// se le mostraba a la persona un "no se pudo cargar tu configuración",
/// igual que si fuera un fallo de red.
///
/// DESTINO: capa de datos. La lanza [NegocioRepository] al leer el negocio;
/// la capa de presentación la captura aparte para poder distinguirla de
/// cualquier otro error de Firestore.
///
/// No repara nada a propósito: borrar el `negocioId`, crear un negocio
/// nuevo o relajar las reglas son decisiones de producto, no de esta capa.
class NegocioInexistenteException implements Exception {
  const NegocioInexistenteException({required this.negocioId, this.uid});

  /// Id que el perfil referencia y que no se encuentra en `negocios/`.
  final String negocioId;

  /// Usuario dueño del perfil que referencia el negocio, cuando se conoce.
  final String? uid;

  String get mensaje {
    final dueno = uid == null ? '' : ' del usuario "$uid"';
    return 'No se encontró el negocio asociado a tu cuenta$dueno. '
        'Vuelve a intentarlo en un momento o contacta a soporte.';
  }

  @override
  String toString() =>
      'NegocioInexistenteException: $negocioId'
      '${uid == null ? '' : ' (referenciado por $uid)'}';
}
