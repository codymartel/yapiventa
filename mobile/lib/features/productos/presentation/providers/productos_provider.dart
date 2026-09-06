import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/productos_repository.dart';
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
  final ProductosRepository _repository;
  final String uid;

  ProductosProvider({
    required this.uid,
    required ProductosRepository repository,
  }) : _repository = repository;

  List<Producto> _productos = [];
  bool _cargando = false;
  bool _cargandoMas = false;
  bool _refrescando = false;
  bool _hayMas = false;
  static const _tamanoPagina = 10;
  int _productosMostrados = _tamanoPagina;
  String _busqueda = '';
  String? _errorMessage;
  DocumentSnapshot<Map<String, dynamic>>? _ultimoDocumento;
  bool _disposed = false;

  // Valores fijos temporales — reemplazar cuando migres AppConfig y el
  // plan real del usuario (igual que webActivaInicial en user_repository.dart).
  int _limiteProductos = 20;
  final int _minimoProductos = 1;

  bool get cargando => _cargando;
  bool get cargandoMas => _cargandoMas;
  bool get refrescando => _refrescando;
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
    _ultimoDocumento = null;
    _hayMas = false;
    _productosMostrados = _tamanoPagina;
    _errorMessage = null;
    _notificar();
    try {
      final pagina = await _repository.obtenerProductos(uid);
      _productos = pagina.productos;
      _ultimoDocumento = pagina.ultimoDocumento;
      _hayMas = pagina.hayMas;
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

    if (_ultimoDocumento == null) return;
    _cargandoMas = true;
    _errorMessage = null;
    _notificar();
    try {
      final pagina = await _repository.obtenerProductos(
        uid,
        despuesDe: _ultimoDocumento,
      );
      final idsCargados = _productos.map((producto) => producto.id).toSet();
      _productos.addAll(
        pagina.productos.where((producto) => idsCargados.add(producto.id)),
      );
      _ultimoDocumento = pagina.ultimoDocumento;
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

  // Equivale al onGuardar del FormularioProducto — crea o actualiza
  // según si el producto ya tiene id.
  Future<bool> guardarProducto(Producto producto) async {
    try {
      // NUEVO — negocioId siempre se fuerza al uid actual aquí, para
      // que quien llame a este método no tenga que acordarse de
      // pasarlo bien cada vez.
      final productoConNegocioId = Producto(
        id: producto.id,
        negocioId: uid,
        nombre: producto.nombre,
        precio: producto.precio,
        stock: producto.stock,
        esStockInfinito: producto.esStockInfinito,
        descripcion: producto.descripcion,
        categoria: producto.categoria,
        disponible: producto.disponible,
        tieneDelivery: producto.tieneDelivery,
        urlImagen: producto.urlImagen,
        cloudinaryPublicId: producto.cloudinaryPublicId,
        unidadMedidaNombre: producto.unidadMedidaNombre,
        fraccionesSeleccionadas: producto.fraccionesSeleccionadas,
        fechaVencimiento: producto.fechaVencimiento,
      );
      final esNuevo = productoConNegocioId.id.isEmpty;
      final productoId = await _repository.guardarProducto(
        uid,
        productoConNegocioId,
      );
      if (esNuevo) {
        _productos.removeWhere(
          (productoCargado) => productoCargado.id == productoId,
        );
      }
      final productoGuardado = Producto(
        id: productoId,
        negocioId: productoConNegocioId.negocioId,
        nombre: productoConNegocioId.nombre,
        precio: productoConNegocioId.precio,
        stock: productoConNegocioId.stock,
        esStockInfinito: productoConNegocioId.esStockInfinito,
        descripcion: productoConNegocioId.descripcion,
        categoria: productoConNegocioId.categoria,
        disponible: productoConNegocioId.disponible,
        tieneDelivery: productoConNegocioId.tieneDelivery,
        urlImagen: productoConNegocioId.urlImagen,
        cloudinaryPublicId: productoConNegocioId.cloudinaryPublicId,
        unidadMedidaNombre: productoConNegocioId.unidadMedidaNombre,
        fraccionesSeleccionadas: productoConNegocioId.fraccionesSeleccionadas,
        fechaVencimiento: productoConNegocioId.fechaVencimiento,
      );

      final indiceExistente = _productos.indexWhere(
        (productoCargado) => productoCargado.id == productoId,
      );
      if (esNuevo) {
        _productos.insert(0, productoGuardado);
      } else if (indiceExistente != -1) {
        _productos[indiceExistente] = productoGuardado;
      }
      _errorMessage = null;
      _notificar();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo guardar el producto.';
      _notificar();
      return false;
    }
  }

  Future<void> eliminarProducto(String productoId) async {
    try {
      await _repository.eliminarProducto(uid, productoId);
      await cargarProductos();
    } catch (e) {
      _errorMessage = 'No se pudo eliminar el producto.';
      _notificar();
    }
  }

  Future<void> toggleDisponible(String productoId, bool disponible) async {
    try {
      await _repository.toggleDisponible(uid, productoId, disponible);
      await cargarProductos();
    } catch (e) {
      _errorMessage = 'No se pudo actualizar el producto.';
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
