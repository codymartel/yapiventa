import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/negocio/domain/models/catalogo_venta/unidad_registrada.dart';
import 'package:mobile/features/productos/application/services/entrada_numerica.dart';
import 'package:mobile/features/productos/domain/models/familia_unidad.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/calculo_hoja_producto.dart';
import '../../application/services/mensajes_cobro_caja.dart';
import '../../application/services/textos_producto_caja.dart';
import 'secciones_hoja_producto.dart';

/// Qué eligió el cajero al cerrar la hoja.
enum AccionHojaProducto { agregarYCobrar, agregarYSeguir, cambiar }

/// Abre la hoja del producto: hoja desde abajo en celular (menos de 900 px) y
/// diálogo en PC. [onConfirmar] agrega la línea a la venta y devuelve el
/// motivo si no se pudo (por ejemplo, el tope de 30 productos): la hoja lo
/// muestra y NO se cierra. Devuelve la acción elegida, o null si se cerró sin
/// elegir.
Future<AccionHojaProducto?> mostrarHojaProducto(
  BuildContext context, {
  required Producto producto,
  required String? Function(
    SeleccionProductoCaja seleccion,
    AccionHojaProducto accion,
  )
  onConfirmar,
}) {
  Widget contenido(BuildContext c) => HojaProductoCaja(
    producto: producto,
    onConfirmar: onConfirmar,
    onCerrar: (accion) => Navigator.of(c).pop(accion),
  );
  if (MediaQuery.sizeOf(context).width >= 900) {
    return showDialog<AccionHojaProducto>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.superficie,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: contenido(c),
        ),
      ),
    );
  }
  return showModalBottomSheet<AccionHojaProducto>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: contenido,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// HojaProductoCaja
// ═════════════════════════════════════════════════════════════════════════
// La hoja para elegir un producto (maqueta «2 · Producto»):
//   - se cuenta: cantidad con stepper (sube hasta lo que hay);
//   - por medida: cantidades rápidas (¼ kg, ½ kg, 1 kg…) y «Otra cantidad»
//     en la unidad base (350 g);
//   - variable: modelo (color) y fila (talla) con su stock, y extras;
//   - combo: su precio propio y la cantidad.
// Todo se calcula con `CalculoHojaProducto` (enteros). Dos botones: «Agregar
// y cobrar» y «Agregar y seguir», apagados mientras falte algo, con el motivo
// dicho en texto.
// ═════════════════════════════════════════════════════════════════════════
class HojaProductoCaja extends StatefulWidget {
  const HojaProductoCaja({
    super.key,
    required this.producto,
    required this.onConfirmar,
    required this.onCerrar,
  });

  final Producto producto;
  final String? Function(SeleccionProductoCaja, AccionHojaProducto) onConfirmar;
  final ValueChanged<AccionHojaProducto> onCerrar;

  @override
  State<HojaProductoCaja> createState() => _HojaProductoCajaState();
}

class _HojaProductoCajaState extends State<HojaProductoCaja> {
  late SeleccionProductoCaja _sel;
  final TextEditingController _otra = TextEditingController();
  bool _otraCantidad = false;
  String? _errorOtra;
  String? _errorAgregar;

  Producto get _p => widget.producto;
  bool get _porMedida => _p.esPorMedida && !_p.esCombo;

  @override
  void initState() {
    super.initState();
    var sel = SeleccionProductoCaja(cantidad: _porMedida ? 0 : 1);
    // Con un solo modelo (o una sola fila) no hay nada que elegir.
    if (_p.tieneModelos && !_p.esCombo && _p.modelos.length == 1) {
      sel = sel.conModelo(_p.modelos.first.id);
      if (_p.modelos.first.filas.length == 1) {
        sel = sel.copyWith(filaId: _p.modelos.first.filas.first.id);
      }
    }
    _sel = sel;
  }

  @override
  void dispose() {
    _otra.dispose();
    super.dispose();
  }

  void _cambiar(SeleccionProductoCaja nueva) {
    setState(() {
      _sel = nueva;
      _errorAgregar = null;
    });
  }

  void _elegirModelo(String id) {
    var nueva = _sel.conModelo(id);
    final modelo = _p.modelos.firstWhere((m) => m.id == id);
    if (modelo.filas.length == 1) {
      nueva = nueva.copyWith(filaId: modelo.filas.first.id);
    }
    _cambiar(nueva);
  }

  void _escribirOtra(String texto) {
    final familia = _p.medidaFamilia;
    if (familia == null) return;
    final base = _unidadBase(familia);
    final r = textoAUnidadBase(texto, 1, unidadBase: base.nombre);
    setState(() {
      _errorAgregar = null;
      if (texto.trim().isEmpty) {
        _errorOtra = null;
        _sel = _sel.copyWith(cantidad: 0);
      } else if (r.esValida) {
        _errorOtra = null;
        _sel = _sel.copyWith(cantidad: r.base!);
      } else {
        _errorOtra = r.error;
        _sel = _sel.copyWith(cantidad: 0);
      }
    });
  }

  UnidadRegistrada _unidadBase(FamiliaUnidad familia) {
    return RegistroUnidades.unidadesDe(
      familia,
    ).firstWhere((u) => u.factorBase == 1);
  }

  void _agregar(AccionHojaProducto accion) {
    final error = widget.onConfirmar(_sel, accion);
    if (error != null) {
      setState(() => _errorAgregar = error);
      return;
    }
    widget.onCerrar(accion);
  }

  @override
  Widget build(BuildContext context) {
    final resumen = CalculoHojaProducto.calcular(_p, _sel);
    final sinStock = resumen.stockDisponible == 0;
    final cuerpo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Encabezado(
          producto: _p,
          onCambiar: () => widget.onCerrar(AccionHojaProducto.cambiar),
        ),
        if (_p.tieneModelos && !_p.esCombo) ..._variables(),
        if (_p.extras.isNotEmpty && !_porMedida && !_p.esCombo) ..._extras(),
        if (_porMedida) ..._peso(resumen) else ..._contable(resumen),
        const SizedBox(height: 16),
        _Total(
          resumen: resumen,
          porMedida: _porMedida,
          sinStock: sinStock,
          cantidadElegida: _sel.cantidad,
          falta: _faltaElegir(resumen),
        ),
        if (_errorAgregar != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _errorAgregar!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: resumen.puedeAgregar
              ? () => _agregar(AccionHojaProducto.agregarYCobrar)
              : null,
          child: Text(
            resumen.puedeAgregar
                ? 'Agregar y cobrar · ${MensajesCobroCaja.dinero(resumen.subtotalCentavos)}'
                : 'Agregar y cobrar',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.azulTexto,
            side: const BorderSide(color: AppColors.hint),
          ),
          onPressed: resumen.puedeAgregar
              ? () => _agregar(AccionHojaProducto.agregarYSeguir)
              : null,
          child: const Text('Agregar y seguir'),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(child: cuerpo),
    );
  }

  /// Qué falta elegir, dicho con la palabra del vendedor («Falta elegir:
  /// color», «Falta elegir: talla»). Sin artículos: no hay que acertar el
  /// género.
  String? _faltaElegir(ResumenHojaProducto r) {
    if (r.linea != null) return null;
    if (_p.tieneModelos && !_p.esCombo) {
      final hayModelo = _p.modelos.any((m) => m.id == _sel.modeloId);
      final palabra = hayModelo
          ? (_p.tituloFilas.trim().isEmpty ? 'cómo se vende' : _p.tituloFilas)
          : (_p.tituloModelos.trim().isEmpty ? 'modelo' : _p.tituloModelos);
      return 'Falta elegir: ${palabra.trim().toLowerCase()}.';
    }
    return r.falta;
  }

  // ── Variables: modelo y fila ──────────────────────────────────────────
  List<Widget> _variables() {
    final modelos = _p.modelos;
    final modelo = modelos.where((m) => m.id == _sel.modeloId).firstOrNull;
    return [
      if (modelos.length > 1) ...[
        TituloSeccion(_p.tituloModelos.isEmpty ? 'Modelo' : _p.tituloModelos),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in modelos)
              OpcionChip(
                etiqueta: m.nombre,
                activa: m.id == _sel.modeloId,
                onTap: () => _elegirModelo(m.id),
              ),
          ],
        ),
      ],
      if (modelo != null && modelo.filas.length > 1) ...[
        TituloSeccion(_p.tituloFilas.isEmpty ? 'Se vende en' : _p.tituloFilas),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in modelo.filas)
              FilaOpcion(
                fila: f,
                stockTexto: _p.esStockInfinito
                    ? ''
                    : stockDeFila(f, porMedida: _porMedida),
                activa: f.id == _sel.filaId,
                // Con stock ilimitado las filas guardan 0: no están agotadas.
                agotada:
                    !_p.esStockInfinito &&
                    (_porMedida ? (f.stockBase ?? 0) <= 0 : f.stock <= 0),
                onTap: () => _cambiar(_sel.copyWith(filaId: f.id)),
              ),
          ],
        ),
      ],
    ];
  }

  // ── Extras ────────────────────────────────────────────────────────────
  List<Widget> _extras() => [
    const TituloSeccion('Extras (opcional)'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in _p.extras)
          OpcionChip(
            etiqueta: etiquetaExtra(e),
            activa: _sel.extrasIds.contains(e.id),
            onTap: () =>
                _cambiar(_sel.conExtra(e.id, !_sel.extrasIds.contains(e.id))),
          ),
      ],
    ),
  ];

  // ── Se cuenta: stepper ────────────────────────────────────────────────
  List<Widget> _contable(ResumenHojaProducto r) {
    final maximo = CalculoHojaProducto.maximoDe(_p, _sel);
    return [
      const TituloSeccion('Cantidad'),
      Row(
        children: [
          StepperCantidad(
            cantidad: _sel.cantidad,
            minimo: 1,
            maximo: maximo < 1 ? 1 : maximo,
            onCambio: (n) => _cambiar(_sel.copyWith(cantidad: n)),
          ),
          const SizedBox(width: 12),
          if (r.stockDisponible != null && r.stockDisponible! > 0)
            Expanded(
              child: Text(
                _sel.cantidad >= r.stockDisponible!
                    ? 'Es todo lo que hay'
                    : 'Hay ${r.stockDisponible}',
                style: TextStyle(
                  color: _sel.cantidad >= r.stockDisponible!
                      ? AppColors.aviso
                      : AppColors.muted,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    ];
  }

  // ── Por medida: cantidades rápidas y otra cantidad ────────────────────
  List<Widget> _peso(ResumenHojaProducto r) {
    final familia = _p.medidaFamilia!;
    final rapidas = CalculoHojaProducto.cantidadesRapidas(_p);
    final stock = r.stockDisponible;
    final base = _unidadBase(familia);
    return [
      const TituloSeccion('¿Cuánto se lleva?'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in rapidas)
            OpcionChip(
              etiqueta: c.etiqueta,
              activa: !_otraCantidad && _sel.cantidad == c.base,
              habilitada: stock == null || c.base <= stock,
              onTap: () {
                _otraCantidad = false;
                _errorOtra = null;
                _cambiar(_sel.copyWith(cantidad: c.base));
              },
            ),
          OpcionChip(
            etiqueta: 'Otra cantidad',
            activa: _otraCantidad,
            onTap: () {
              setState(() {
                _otraCantidad = true;
                _sel = _sel.copyWith(cantidad: 0);
                _otra.clear();
              });
            },
          ),
        ],
      ),
      if (_otraCantidad) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _otra,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppColors.texto, fontSize: 16),
          cursorColor: AppColors.azulTexto,
          decoration: InputDecoration(
            hintText: 'Cantidad en ${base.nombre}',
            suffixText: base.nombre,
            errorText: _errorOtra,
            border: const OutlineInputBorder(),
          ),
          onChanged: _escribirOtra,
        ),
      ],
    ];
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.producto, required this.onCambiar});

  final Producto producto;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final precio = TextosProductoCaja.precio(producto);
    final stock = producto.esCombo || producto.esStockInfinito
        ? ''
        : TextosProductoCaja.stock(producto);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                producto.nombre,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lineaPrecioStock(precio, stock),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: AppColors.azulTexto,
          ),
          onPressed: onCambiar,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.resumen,
    required this.porMedida,
    required this.sinStock,
    required this.cantidadElegida,
    required this.falta,
  });

  final String? falta;
  final ResumenHojaProducto resumen;
  final bool porMedida;
  final bool sinStock;
  final int cantidadElegida;

  @override
  Widget build(BuildContext context) {
    String? aviso;
    if (sinStock) {
      aviso = 'No hay stock de esto.';
    } else if (resumen.noAlcanza) {
      aviso = 'Pides más de lo que hay.';
    } else if (resumen.linea == null) {
      aviso = porMedida && cantidadElegida == 0
          ? 'Elige cuánto se lleva.'
          : falta;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bordeSutil),
      ),
      child: aviso != null
          ? Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.aviso,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aviso,
                    style: const TextStyle(
                      color: AppColors.aviso,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    resumen.resumen.isEmpty
                        ? 'Total'
                        : (porMedida
                              ? '${resumen.resumen} salen'
                              : resumen.resumen),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  MensajesCobroCaja.dinero(resumen.subtotalCentavos),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    );
  }
}
