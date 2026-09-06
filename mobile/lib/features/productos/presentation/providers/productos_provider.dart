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
  bool _cargando = true;
  bool _refrescando = false;
  String _busqueda = '';
  String? _errorMessage;

  // Valores fijos temporales — reemplazar cuando migres AppConfig y el
  // plan real del usuario (igual que webActivaInicial en user_repository.dart).
  int _limiteProductos = 20;
  final int _minimoProductos = 1;

  bool get cargando => _cargando;
  bool get refrescando => _refrescando;
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
    if (_busqueda.isBlank) return _productos;
    final q = _busqueda.toLowerCase();
    return _productos.where((p) {
      return p.nombre.toLowerCase().contains(q) ||
          p.categoria.toLowerCase().contains(q) ||
          p.descripcion.toLowerCase().contains(q);
    }).toList();
  }

  void actualizarBusqueda(String texto) {
    _busqueda = texto;
    notifyListeners();
  }

  // Equivale a tu `LaunchedEffect(uid) { cargarProductos() }` — se llama
  // una vez al abrir la pantalla.
  Future<void> cargarProductos() async {
    _cargando = true;
    notifyListeners();
    try {
      _productos = await _repository.obtenerProductos(uid);
    } catch (e) {
      _errorMessage = 'No se pudieron cargar tus productos.';
    } finally {
      _cargando = false;
      _refrescando = false;
      notifyListeners();
    }
  }

  // Equivale a tu PullToRefreshBox → onRefresh.
  Future<void> refrescar() async {
    _refrescando = true;
    notifyListeners();
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
      );
      await _repository.guardarProducto(uid, productoConNegocioId);
      await cargarProductos();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo guardar el producto.';
      notifyListeners();
      return false;
    }
  }

  Future<void> eliminarProducto(String productoId) async {
    try {
      await _repository.eliminarProducto(uid, productoId);
      await cargarProductos();
    } catch (e) {
      _errorMessage = 'No se pudo eliminar el producto.';
      notifyListeners();
    }
  }

  Future<void> toggleDisponible(String productoId, bool disponible) async {
    try {
      await _repository.toggleDisponible(uid, productoId, disponible);
      await cargarProductos();
    } catch (e) {
      _errorMessage = 'No se pudo actualizar el producto.';
      notifyListeners();
    }
  }

  void limpiarError() {
    _errorMessage = null;
    notifyListeners();
  }
}

extension on String {
  bool get isBlank => trim().isEmpty;
}