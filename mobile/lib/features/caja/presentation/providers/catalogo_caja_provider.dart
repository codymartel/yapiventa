import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/productos/application/services/campos_catalogo_producto.dart';
import 'package:mobile/features/productos/application/use_cases/buscar_productos_caja.dart';
import 'package:mobile/features/productos/domain/models/consulta_catalogo_caja.dart';
import 'package:mobile/features/productos/domain/models/pagina_productos.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../application/services/disponibilidad_caja.dart';

class _Pagina {
  _Pagina(this.productos, this.cursor, this.hayMas);

  final List<Producto> productos;
  CursorProductos? cursor;
  bool hayMas;
}

// ═════════════════════════════════════════════════════════════════════════
// CatalogoCajaProvider
// ═════════════════════════════════════════════════════════════════════════
// El catálogo que ve el cajero: de 20 en 20, con buscador, filtros y orden.
//
// Ahorro de lecturas (cada página nueva cuesta 20):
//   - lo escrito en el buscador espera [pausa] antes de consultar y con menos
//     de 2 letras no consulta;
//   - cada consulta distinta se guarda en MEMORIA de la sesión: volver a un
//     filtro o a una búsqueda ya hecha cuesta 0 lecturas;
//   - «solo con stock» filtra lo ya cargado, sin consultar.
// `reiniciar()` olvida la memoria (por ejemplo, si un precio cambió).
//
// Un resultado que llega tarde de una consulta vieja se descarta.
// ═════════════════════════════════════════════════════════════════════════
class CatalogoCajaProvider extends ChangeNotifier {
  CatalogoCajaProvider({
    required this.negocioId,
    required this._buscar,
    this.pausa = const Duration(milliseconds: 350),
  });

  final String negocioId;
  final BuscarProductosCaja _buscar;
  final Duration pausa;

  final Map<String, _Pagina> _memoria = {};
  Timer? _espera;
  int _generacion = 0;
  bool _cerrado = false;

  /// Lo que el cajero tiene escrito (se ve al instante en el campo).
  String _texto = '';
  String? _tipo;
  String? _categoria;
  OrdenCatalogoCaja _orden = OrdenCatalogoCaja.frecuentes;
  bool _soloConStock = false;

  /// El texto con el que SÍ se consulta: vacío si tiene menos de 2 letras.
  String _textoActivo = '';

  List<Producto> _productos = const [];
  bool _cargando = false;
  bool _cargandoMas = false;
  bool _hayMas = false;
  String? _error;

  String get texto => _texto;
  String? get tipo => _tipo;
  String? get categoria => _categoria;
  OrdenCatalogoCaja get orden => _orden;
  bool get soloConStock => _soloConStock;
  bool get cargando => _cargando;
  bool get cargandoMas => _cargandoMas;
  bool get hayMas => _hayMas;
  String? get error => _error;

  /// Con texto el orden es por nombre, sea cual sea el elegido.
  bool get buscando => _textoActivo.isNotEmpty;

  /// Los productos de la consulta; con «solo con stock», los que tienen.
  List<Producto> get productos => _soloConStock
      ? _productos.where(DisponibilidadCaja.tieneStock).toList()
      : _productos;

  bool get vacio => !_cargando && _error == null && productos.isEmpty;

  String get _clave =>
      '${_tipo ?? ''}|${_categoria ?? ''}|${buscando ? 'nombre' : _orden.name}'
      '|$_textoActivo';

  ConsultaCatalogoCaja get _consulta => ConsultaCatalogoCaja(
    texto: _textoActivo,
    tipo: _tipo,
    categoria: _categoria,
    orden: _orden,
  );

  Future<void> iniciar() => _cargarPrimera();

  // ── Cambios que consultan ─────────────────────────────────────────────

  /// El cajero escribe. Se consulta tras [pausa] y solo si el texto efectivo
  /// (vacío o de 2 letras o más) cambió.
  void escribir(String valor) {
    _texto = valor;
    _espera?.cancel();
    notifyListeners();
    _espera = Timer(pausa, () {
      final normal = CamposCatalogoProducto.nombreBusqueda(_texto);
      final activo = normal.length >= CamposCatalogoProducto.minimoLetras
          ? normal
          : '';
      if (activo == _textoActivo) return;
      _textoActivo = activo;
      _cargarPrimera();
    });
  }

  void limpiarBusqueda() {
    _espera?.cancel();
    _texto = '';
    if (_textoActivo.isEmpty) {
      notifyListeners();
      return;
    }
    _textoActivo = '';
    _cargarPrimera();
  }

  /// Cambia tipo y categoría a la vez y consulta UNA sola vez (un filtro
  /// rápido reemplaza al anterior: no son dos consultas).
  void aplicarFiltro({String? tipo, String? categoria}) {
    if (_tipo == tipo && _categoria == categoria) return;
    _tipo = tipo;
    _categoria = categoria;
    _cargarPrimera();
  }

  void cambiarTipo(String? tipo) {
    if (_tipo == tipo) return;
    _tipo = tipo;
    _cargarPrimera();
  }

  void cambiarCategoria(String? categoria) {
    if (_categoria == categoria) return;
    _categoria = categoria;
    _cargarPrimera();
  }

  void cambiarOrden(OrdenCatalogoCaja orden) {
    if (_orden == orden) return;
    _orden = orden;
    if (!buscando) {
      _cargarPrimera();
    } else {
      notifyListeners();
    }
  }

  /// Filtra lo ya cargado: no consulta.
  void cambiarSoloConStock(bool valor) {
    if (_soloConStock == valor) return;
    _soloConStock = valor;
    notifyListeners();
  }

  /// Olvida lo guardado en memoria y vuelve a consultar.
  Future<void> reiniciar() {
    _memoria.clear();
    return _cargarPrimera();
  }

  // ── Carga ─────────────────────────────────────────────────────────────

  Future<void> _cargarPrimera() async {
    final clave = _clave;
    final generacion = ++_generacion;
    _error = null;
    _cargandoMas = false;

    final guardada = _memoria[clave];
    if (guardada != null) {
      _mostrar(guardada);
      _cargando = false;
      _avisar();
      return;
    }

    _cargando = true;
    _productos = const [];
    _hayMas = false;
    _avisar();
    try {
      final pagina = await _buscar(negocioId: negocioId, consulta: _consulta);
      if (generacion != _generacion) return;
      // Copia propia: «ver más» le agrega productos y el repositorio podría
      // devolver una lista que no se puede modificar.
      final nueva = _Pagina(
        List.of(pagina.productos),
        pagina.ultimoCursor,
        pagina.hayMas,
      );
      _memoria[clave] = nueva;
      _mostrar(nueva);
    } catch (_) {
      if (generacion != _generacion) return;
      _error = 'No se pudo cargar el catálogo. Revisa tu conexión.';
    } finally {
      if (generacion == _generacion) {
        _cargando = false;
        _avisar();
      }
    }
  }

  /// «Ver más»: trae los 20 siguientes y los suma a lo guardado.
  Future<void> verMas() async {
    if (!_hayMas || _cargando || _cargandoMas) return;
    final guardada = _memoria[_clave];
    if (guardada == null) return;
    final generacion = _generacion;
    _cargandoMas = true;
    _error = null;
    _avisar();
    try {
      final pagina = await _buscar(
        negocioId: negocioId,
        consulta: _consulta,
        despuesDe: guardada.cursor,
      );
      if (generacion != _generacion) return;
      guardada.productos.addAll(pagina.productos);
      guardada.cursor = pagina.ultimoCursor ?? guardada.cursor;
      guardada.hayMas = pagina.hayMas;
      _mostrar(guardada);
    } catch (_) {
      if (generacion != _generacion) return;
      _error = 'No se pudo cargar más. Revisa tu conexión.';
    } finally {
      if (generacion == _generacion) {
        _cargandoMas = false;
        _avisar();
      }
    }
  }

  void _mostrar(_Pagina p) {
    _productos = List.unmodifiable(p.productos);
    _hayMas = p.hayMas;
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _espera?.cancel();
    super.dispose();
  }
}
