import 'package:flutter/foundation.dart';
import '../../application/use_cases/cambiar_disponibilidad_producto.dart';
import '../../application/use_cases/crear_producto.dart';
import '../../application/use_cases/editar_producto.dart';
import '../../application/use_cases/eliminar_producto.dart';
import '../../application/use_cases/obtener_pagina_productos.dart';
import '../../domain/models/pagina_productos.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// ProductosProvider
// ═════════════════════════════════════════════════════════════════════════
// Equivalente a la lógica de estado de tu ProductosScreen.kt (todos los
// `remember { mutableStateOf(...) }`). El "mesero": recibe pedidos de la
// pantalla, se los lleva a ProductosRepository (la "cocina"), y guarda
// el resultado para que la UI lo lea.
//
// QUÉ NO HACE:
// - NO habla con Firestore directo — eso es ProductosRepository.
// - NO sabe nada de widgets, colores, ni Scaffold.
//
// PENDIENTE (marcado explícito, igual que en otros providers): el límite
// de productos venía en tu Kotlin de `AppConfig.limiteProductos` — ese
// archivo aún no está migrado a Flutter, así que aquí se usa un valor
// fijo temporal hasta que migres core/config/app_config.dart.
// ═════════════════════════════════════════════════════════════════════════

class ProductosProvider extends ChangeNotifier {
  final CambiarDisponibilidadProducto _cambiarDisponibilidadProducto;
  final CrearProducto _crearProducto;
  final EditarProducto _editarProducto;
  final EliminarProducto _eliminarProducto;
  final ObtenerPaginaProductos _obtenerPaginaProductos;
  final String uid;

  factory ProductosProvider({
    required String uid,
    required CambiarDisponibilidadProducto cambiarDisponibilidadProducto,
    required CrearProducto crearProducto,
    required EditarProducto editarProducto,
    required EliminarProducto eliminarProducto,
    required ObtenerPaginaProductos obtenerPaginaProductos,
  }) {
    return ProductosProvider._(
      uid,
      cambiarDisponibilidadProducto,
      crearProducto,
      editarProducto,
      eliminarProducto,
      obtenerPaginaProductos,
    );
  }

  ProductosProvider._(
    this.uid,
    this._cambiarDisponibilidadProducto,
    this._crearProducto,
    this._editarProducto,
    this._eliminarProducto,
    this._obtenerPaginaProductos,
  );

  List<Producto> _productos = [];
  bool _cargando = false;
  bool _cargandoMas = false;
  bool _refrescando = false;
  bool _creandoProducto = false;
  bool _editandoProducto = false;
  final Set<String> _productosCambiandoDisponibilidad = {};
  bool _hayMas = false;
  static const _tamanoPagina = 10;
  int _productosMostrados = _tamanoPagina;
  String _busqueda = '';
  String? _errorMessage;
  CursorProductos? _ultimoCursor;
  bool _disposed = false;

  // Valores fijos temporales — reemplazar cuando migres AppConfig y el
  // plan real del usuario (igual que webActivaInicial en user_repository.dart).
  final int _limiteProductos = 20;
  final int _minimoProductos = 1;

  bool get cargando => _cargando;
  bool get cargandoMas => _cargandoMas;
  bool get refrescando => _refrescando;
  bool get creandoProducto => _creandoProducto;
  bool get editandoProducto => _editandoProducto;
  bool cambiandoDisponibilidad(String productoId) =>
      _productosCambiandoDisponibilidad.contains(productoId);
  bool get hayMas => _hayMas || _productos.length > _productosMostrados;
  String get busqueda => _busqueda;
  String? get errorMessage => _errorMessage;
  int get totalProductos => _productos.length;
  int get limiteProductos => _limiteProductos;
  int get minimoProductos => _minimoProductos;

  bool get minimoAlcanzado => totalProductos >= _minimoProductos;
  bool get limiteAlcanzado => totalProductos >= _limiteProductos;

  // Equivale a tu `productosFiltrados` — busca en nombre, categoría y
  // descripción, igual que en Kotlin.
  List<Producto> get productosFiltrados {
    if (_busqueda.isBlank) {
      return List.unmodifiable(_productos.take(_productosMostrados));
    }
    final q = _busqueda.toLowerCase();
    return _productos
        .where((p) {
          return p.nombre.toLowerCase().contains(q) ||
              p.categoria.toLowerCase().contains(q) ||
              p.descripcion.toLowerCase().contains(q);
        })
        .take(_productosMostrados)
        .toList();
  }

  void actualizarBusqueda(String texto) {
    _busqueda = texto;
    _notificar();
  }

  // Equivale a tu `LaunchedEffect(uid) { cargarProductos() }` — se llama
  // una vez al abrir la pantalla. Reinicia el cursor y reemplaza la lista
  // con los 10 productos mas recientes.
  Future<void> cargarProductos() async {
    if (_cargando || _cargandoMas) return;

    _cargando = true;
    _errorMessage = null;
    _notificar();
    try {
      final pagina = await _obtenerPaginaProductos(
        uid: uid,
        limite: _tamanoPagina,
      );
      _productos = List<Producto>.of(pagina.productos);
      _ultimoCursor = pagina.ultimoCursor;
      _hayMas = pagina.hayMas;
      _productosMostrados = _tamanoPagina;
    } catch (e) {
      _errorMessage = 'No se pudieron cargar tus productos.';
    } finally {
      _cargando = false;
      _refrescando = false;
      _notificar();
    }
  }

  // Equivale al boton "Ver mas": continua desde el cursor guardado y
  // anexa solo la siguiente pagina. Los IDs ya presentes se descartan para
  // proteger la lista ante respuestas repetidas o cambios concurrentes.
  Future<void> cargarMasProductos() async {
    if (_cargando || _cargandoMas || !hayMas) {
      return;
    }

    final nuevoLimite = _productosMostrados + _tamanoPagina;
    final productosOcultos = _productos.length - _productosMostrados;
    if (productosOcultos >= _tamanoPagina || !_hayMas) {
      _productosMostrados = nuevoLimite;
      _notificar();
      return;
    }

    if (_ultimoCursor == null) return;
    _cargandoMas = true;
    _errorMessage = null;
    _notificar();
    try {
      final pagina = await _obtenerPaginaProductos(
        uid: uid,
        despuesDe: _ultimoCursor,
        limite: _tamanoPagina,
      );
      final idsCargados = _productos.map((producto) => producto.id).toSet();
      _productos.addAll(
        pagina.productos.where((producto) => idsCargados.add(producto.id)),
      );
      _ultimoCursor = pagina.ultimoCursor;
      _hayMas = pagina.hayMas;
      _productosMostrados = nuevoLimite;
    } catch (e) {
      _errorMessage = 'No se pudieron cargar mas productos.';
    } finally {
      _cargandoMas = false;
      _notificar();
    }
  }

  // Equivale a tu PullToRefreshBox → onRefresh.
  Future<void> refrescar() async {
    if (_cargando || _cargandoMas || _refrescando) return;

    _refrescando = true;
    _notificar();
    await cargarProductos();
  }

  Future<bool> crearProducto(
    Producto producto, {
    Uint8List? imagenBytes,
    String? nombreArchivo,
  }) async {
    if (_creandoProducto) return false;

    _creandoProducto = true;
    _errorMessage = null;
    _notificar();
    try {
      final productoGuardado = await _crearProducto(
        uid: uid,
        producto: producto,
        imagenBytes: imagenBytes,
        nombreArchivo: nombreArchivo,
      );

      final indiceExistente = _productos.indexWhere(
        (productoCargado) => productoCargado.id == productoGuardado.id,
      );
      if (indiceExistente == -1) {
        _productos.insert(0, productoGuardado);
      } else {
        _productos[indiceExistente] = productoGuardado;
      }
      return true;
    } catch (e) {
      _errorMessage = _mensajeErrorGuardado(e);
      return false;
    } finally {
      _creandoProducto = false;
      _notificar();
    }
  }

  Future<bool> guardarProducto(
    Producto producto, {
    Uint8List? imagenBytes,
    String? nombreArchivo,
  }) async {
    if (producto.id.isEmpty) {
      return crearProducto(
        producto,
        imagenBytes: imagenBytes,
        nombreArchivo: nombreArchivo,
      );
    }
    if (_editandoProducto) return false;

    _editandoProducto = true;
    _errorMessage = null;
    _notificar();
    try {
      final productoGuardado = await _editarProducto(
        uid: uid,
        producto: producto,
        imagenBytes: imagenBytes,
        nombreArchivo: nombreArchivo,
      );
      final indiceExistente = _productos.indexWhere(
        (productoCargado) => productoCargado.id == productoGuardado.id,
      );
      if (indiceExistente != -1) {
        _productos[indiceExistente] = productoGuardado;
      }
      return true;
    } catch (e) {
      _errorMessage = _mensajeErrorGuardado(e);
      return false;
    } finally {
      _editandoProducto = false;
      _notificar();
    }
  }

  String _mensajeErrorGuardado(Object error) {
    final detalle = error.toString().replaceFirst('Exception: ', '');
    return 'No se pudo guardar el producto: $detalle';
  }

  Future<bool> eliminarProducto(String productoId) async {
    _errorMessage = null;
    _notificar();
    try {
      await _eliminarProducto(uid: uid, productoId: productoId);
      _productos.removeWhere((producto) => producto.id == productoId);
      _notificar();
      return true;
    } catch (_) {
      _errorMessage = 'No se pudo eliminar el producto.';
      _notificar();
      return false;
    }
  }

  Future<bool> toggleDisponible(String productoId, bool disponible) async {
    if (!_productosCambiandoDisponibilidad.add(productoId)) return false;

    _errorMessage = null;
    _notificar();
    try {
      await _cambiarDisponibilidadProducto(
        uid: uid,
        productoId: productoId,
        disponible: disponible,
      );
      final indice = _productos.indexWhere(
        (producto) => producto.id == productoId,
      );
      if (indice != -1) {
        _productos[indice] = _productos[indice].copyWith(
          disponible: disponible,
        );
      }
      return true;
    } catch (_) {
      _errorMessage = 'No se pudo actualizar el producto.';
      return false;
    } finally {
      _productosCambiandoDisponibilidad.remove(productoId);
      _notificar();
    }
  }

  void limpiarError() {
    _errorMessage = null;
    _notificar();
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

extension on String {
  bool get isBlank => trim().isEmpty;
}
