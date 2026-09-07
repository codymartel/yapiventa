import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/producto.dart';

abstract final class ProductoFirestoreMapper {
  static Producto? desdeFirestore(String id, Map<String, dynamic>? data) {
    final nombre = data?['nombre'] as String?;
    final negocioId = data?['negocioId'] as String?;
    if (data == null || nombre == null || negocioId == null) return null;

    return Producto(
      id: id,
      negocioId: negocioId,
      nombre: nombre,
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      esStockInfinito: data['esStockInfinito'] as bool? ?? false,
      descripcion: data['descripcion'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      disponible: data['disponible'] as bool? ?? true,
      tieneDelivery: data['tieneDelivery'] as bool? ?? false,
      urlImagen: data['urlImagen'] as String? ?? '',
      cloudinaryPublicId: data['cloudinaryPublicId'] as String?,
      unidadMedidaNombre: data['unidadMedidaNombre'] as String? ?? '',
      fraccionesSeleccionadas:
          (data['fraccionesSeleccionadas'] as List?)?.cast<String>() ?? [],
      fechaVencimiento: (data['fechaVencimiento'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> paraFirestore(Producto producto) {
    return {
      'negocioId': producto.negocioId,
      'nombre': producto.nombre,
      'precio': producto.precio,
      'stock': producto.stock,
      'esStockInfinito': producto.esStockInfinito,
      'descripcion': producto.descripcion,
      'categoria': producto.categoria,
      'disponible': producto.disponible,
      'tieneDelivery': producto.tieneDelivery,
      'urlImagen': producto.urlImagen,
      'cloudinaryPublicId': producto.cloudinaryPublicId,
      'unidadMedidaNombre': producto.unidadMedidaNombre,
      'fraccionesSeleccionadas': producto.fraccionesSeleccionadas,
      'fechaVencimiento': producto.fechaVencimiento == null
          ? null
          : Timestamp.fromDate(producto.fechaVencimiento!),
    };
  }
}
