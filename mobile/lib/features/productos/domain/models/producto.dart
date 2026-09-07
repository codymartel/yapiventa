// ═════════════════════════════════════════════════════════════════════════
// Producto
// ═════════════════════════════════════════════════════════════════════════
// fec/2026: agregado fechaVencimiento (DateTime?, opcional). Si es null,
// el producto no tiene caducidad y no se muestra gestión de vencimiento.
// Migración de tu `data class Producto`. Dos campos agregados respecto
// al Kotlin original, por decisiones tomadas en esta sesión:
//   - negocioId: hoy vale lo mismo que el uid del dueño, pero deja la
//     puerta abierta a colaboradores/roles compartiendo un negocio sin
//     tener que migrar datos después.
//   - cloudinaryPublicId: no se usa todavía (Cloudinary aún no está
//     conectado), pero se guarda desde ya para poder borrar imágenes
//     de Cloudinary en el futuro sin tener que rastrear fotos viejas
//     sin ID.
// ═════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

class Producto {
  final String id;
  final String negocioId;
  final String nombre;
  final double precio;
  final int stock;
  final bool esStockInfinito;
  final String descripcion;
  final String categoria;
  final bool disponible;
  final bool tieneDelivery;
  final String urlImagen;
  final String? cloudinaryPublicId;
  final String unidadMedidaNombre;
  final List<String> fraccionesSeleccionadas;
  final DateTime? fechaVencimiento;

  Producto({
    this.id = '',
    required this.negocioId,
    required this.nombre,
    this.precio = 0.0,
    this.stock = 0,
    this.esStockInfinito = false,
    this.descripcion = '',
    this.categoria = '',
    this.disponible = true,
    this.tieneDelivery = false,
    this.urlImagen = '',
    this.cloudinaryPublicId,
    this.unidadMedidaNombre = '',
    this.fraccionesSeleccionadas = const [],
    this.fechaVencimiento,
  });

  Producto copyWith({
    String? id,
    String? negocioId,
    String? nombre,
    double? precio,
    int? stock,
    bool? esStockInfinito,
    String? descripcion,
    String? categoria,
    bool? disponible,
    bool? tieneDelivery,
    String? urlImagen,
    String? cloudinaryPublicId,
    String? unidadMedidaNombre,
    List<String>? fraccionesSeleccionadas,
    DateTime? fechaVencimiento,
  }) {
    return Producto(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      esStockInfinito: esStockInfinito ?? this.esStockInfinito,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      disponible: disponible ?? this.disponible,
      tieneDelivery: tieneDelivery ?? this.tieneDelivery,
      urlImagen: urlImagen ?? this.urlImagen,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      unidadMedidaNombre: unidadMedidaNombre ?? this.unidadMedidaNombre,
      fraccionesSeleccionadas:
          fraccionesSeleccionadas ?? this.fraccionesSeleccionadas,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
    );
  }

  static Producto? fromMap(String id, Map<String, dynamic>? data) {
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

  Map<String, dynamic> toMap() {
    return {
      'negocioId': negocioId,
      'nombre': nombre,
      'precio': precio,
      'stock': stock,
      'esStockInfinito': esStockInfinito,
      'descripcion': descripcion,
      'categoria': categoria,
      'disponible': disponible,
      'tieneDelivery': tieneDelivery,
      'urlImagen': urlImagen,
      'cloudinaryPublicId': cloudinaryPublicId,
      'unidadMedidaNombre': unidadMedidaNombre,
      'fraccionesSeleccionadas': fraccionesSeleccionadas,
      'fechaVencimiento': fechaVencimiento,
    };
  }
}
