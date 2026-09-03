class Producto {
  final String id;
  final String nombre;
  final double precio;
  final int stock;
  final bool esStockInfinito;
  final String descripcion;
  final String categoria;
  final bool disponible;
  final bool tieneDelivery;
  final String urlImagen;
  final String unidadMedidaNombre;
  final List<String> fraccionesSeleccionadas;

  Producto({
    this.id = '',
    required this.nombre,
    this.precio = 0.0,
    this.stock = 0,
    this.esStockInfinito = false,
    this.descripcion = '',
    this.categoria = '',
    this.disponible = true,
    this.tieneDelivery = false,
    this.urlImagen = '',
    this.unidadMedidaNombre = '',
    this.fraccionesSeleccionadas = const [],
  });

  static Producto? fromMap(String id, Map<String, dynamic>? data) {
    final nombre = data?['nombre'] as String?;
    if (data == null || nombre == null) return null;

    return Producto(
      id: id,
      nombre: nombre,
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      esStockInfinito: data['esStockInfinito'] as bool? ?? false,
      descripcion: data['descripcion'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      disponible: data['disponible'] as bool? ?? true,
      tieneDelivery: data['tieneDelivery'] as bool? ?? false,
      urlImagen: data['urlImagen'] as String? ?? '',
      unidadMedidaNombre: data['unidadMedidaNombre'] as String? ?? '',
      fraccionesSeleccionadas:
          (data['fraccionesSeleccionadas'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'precio': precio,
      'stock': stock,
      'esStockInfinito': esStockInfinito,
      'descripcion': descripcion,
      'categoria': categoria,
      'disponible': disponible,
      'tieneDelivery': tieneDelivery,
      'urlImagen': urlImagen,
      'unidadMedidaNombre': unidadMedidaNombre,
      'fraccionesSeleccionadas': fraccionesSeleccionadas,
    };
  }
}