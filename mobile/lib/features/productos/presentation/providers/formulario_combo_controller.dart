import 'package:flutter/widgets.dart';

import '../../application/services/calculo_combo.dart';
import '../../application/services/entrada_numerica.dart';
import '../../application/services/sugerencias_combo.dart';
import '../../domain/models/estructura_producto.dart';
import '../../domain/models/producto.dart';

// ═════════════════════════════════════════════════════════════════════════
// FormularioComboController
// ═════════════════════════════════════════════════════════════════════════
// Estado del COMBO del formulario de producto: «¿es un combo?» (Sí/No), sus
// partes y su precio. El combo no tiene stock propio: su stock y la suma de
// las partes se calculan (CalculoCombo) con los productos cargados.
//
// REGLAS:
//   - Máximo [ParteCombo.maximo] partes; la misma parte no se repite: se suma
//     su cantidad. Al menos 2 partes para guardar.
//   - El precio arranca con la suma de las partes, pero lo decide el
//     encargado: si lo escribe, no se mueve solo.
//   - Todo en céntimos enteros, nunca double.
// ═════════════════════════════════════════════════════════════════════════
class FormularioComboController extends ChangeNotifier {
  FormularioComboController({
    required this.nombre,
    required this.productos,
    required this.idPropio,
  });

  /// La palabra del rubro («combo», «kit»…).
  final NombreCombo nombre;

  /// Los productos cargados en el panel (de donde se eligen las partes).
  final List<Producto> productos;

  /// El id del producto que se edita ('' si es nuevo): no puede incluirse a sí
  /// mismo.
  final String idPropio;

  /// «¿Es un combo?»: Sí.
  bool usa = false;

  final List<ParteCombo> partes = [];
  final TextEditingController precioCtrl = TextEditingController();

  /// El encargado escribió su propio precio: ya no se propone la suma.
  bool _precioPropio = false;

  /// Lo que sumaban las partes cuando se guardó el precio (aviso de cambio).
  int _sumaGuardada = 0;

  Producto? buscar(String id) {
    for (final producto in productos) {
      if (producto.id == id) return producto;
    }
    return null;
  }

  /// Los productos que se pueden poner en un combo: los que se cuentan, sin
  /// combos dentro de combos ni él mismo.
  List<Producto> get elegibles => [
    for (final producto in productos)
      if (!producto.esCombo &&
          !producto.esPorMedida &&
          producto.id.isNotEmpty &&
          producto.id != idPropio)
        producto,
  ];

  bool get puedeAgregar => partes.length < ParteCombo.maximo;

  /// Las fotos de las partes (de las que tienen): forman la imagen conjunta
  /// del combo cuando no sube una propia.
  List<String> get fotosDeLasPartes => [
    for (final parte in partes)
      if (parte.urlImagen.isNotEmpty) parte.urlImagen,
  ];

  ResultadoCombo get resultado => CalculoCombo.calcular(partes, buscar);

  int? get precioCentavos => textoACentavos(precioCtrl.text);

  /// Cuánto ahorra el cliente (suma − precio); null si no hay ahorro.
  int? get ahorroCentavos {
    final suma = resultado.sumaCentavos;
    final precio = precioCentavos;
    if (suma == null || precio == null || precio <= 0 || precio >= suma) {
      return null;
    }
    return suma - precio;
  }

  /// «Las partes ahora suman S/ 34.00»: las partes cambiaron desde que se
  /// fijó el precio. null si no cambió o no se puede saber.
  String? get avisoPartesCambiaron {
    final suma = resultado.sumaCentavos;
    if (!usa || suma == null || _sumaGuardada <= 0 || suma == _sumaGuardada) {
      return null;
    }
    return 'Las partes ahora suman S/ ${centavosATexto(suma)} '
        '(antes S/ ${centavosATexto(_sumaGuardada)}).';
  }

  // ── Precarga ──────────────────────────────────────────────────────────

  void precargar(Producto producto) {
    if (!producto.esCombo) return;
    usa = true;
    partes.addAll(producto.partes);
    precioCtrl.text = centavosATexto(producto.precioCentavos);
    _precioPropio = true;
    _sumaGuardada = producto.sumaPartesCentavos;
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  void activar(bool valor) {
    usa = valor;
    notifyListeners();
  }

  /// Agrega una parte; si ya estaba, suma la cantidad.
  void agregar(ParteCombo parte) {
    if (parte.cantidad < 1) return;
    final indice = partes.indexWhere((p) => p.clave == parte.clave);
    if (indice != -1) {
      partes[indice] = partes[indice].conCantidad(
        partes[indice].cantidad + parte.cantidad,
      );
    } else if (puedeAgregar) {
      partes.add(parte);
    } else {
      return;
    }
    _proponerPrecio();
    notifyListeners();
  }

  void quitar(int indice) {
    if (indice < 0 || indice >= partes.length) return;
    partes.removeAt(indice);
    _proponerPrecio();
    notifyListeners();
  }

  void cambiarCantidad(int indice, int delta) {
    if (indice < 0 || indice >= partes.length) return;
    final nueva = partes[indice].cantidad + delta;
    if (nueva < 1) return;
    partes[indice] = partes[indice].conCantidad(nueva);
    _proponerPrecio();
    notifyListeners();
  }

  /// El encargado escribió el precio. Si lo deja vacío, vuelve a proponerse
  /// la suma.
  void trasCambioPrecio() {
    _precioPropio = precioCtrl.text.trim().isNotEmpty;
    if (!_precioPropio) _proponerPrecio();
    notifyListeners();
  }

  /// Pone como precio la suma de las partes («Usar la suma»).
  void usarLaSuma() {
    final suma = resultado.sumaCentavos;
    if (suma == null) return;
    precioCtrl.text = centavosATexto(suma);
    _precioPropio = false;
    notifyListeners();
  }

  void _proponerPrecio() {
    if (_precioPropio) return;
    final suma = resultado.sumaCentavos;
    precioCtrl.text = suma == null || suma <= 0 ? '' : centavosATexto(suma);
  }

  // ── Validación y salida ───────────────────────────────────────────────

  /// Lo primero que impide guardar el combo. null si no es combo o está bien.
  String? queFalta() {
    if (!usa) return null;
    final palabra = nombre.palabra;
    if (partes.length < 2) return 'Falta: al menos 2 productos en el $palabra';
    final texto = precioCtrl.text.trim();
    if (texto.isEmpty) return 'Falta: precio del $palabra';
    if ((textoACentavos(texto) ?? 0) <= 0) return 'Revisa: precio del $palabra';
    return null;
  }

  /// Las partes ya como dominio. Vacío si no es combo.
  List<ParteCombo> construir() => usa ? List.unmodifiable(partes) : const [];

  /// Lo que sumaban las partes al guardar (aviso de cambio más adelante).
  int get sumaParaGuardar => usa ? (resultado.sumaCentavos ?? 0) : 0;

  @override
  void dispose() {
    precioCtrl.dispose();
    super.dispose();
  }
}
