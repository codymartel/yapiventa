import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../caja_dependencies.dart';
import '../../domain/models/gasto_caja.dart';
import '../../domain/models/opciones_caja.dart';
import '../../domain/models/resultado_cobro_caja.dart';
import '../providers/catalogo_caja_provider.dart';
import '../providers/dia_caja_provider.dart';
import '../providers/gasto_caja_provider.dart';
import '../providers/gastos_de_hoy_provider.dart';
import '../providers/preparacion_catalogo_provider.dart';
import '../providers/venta_caja_provider.dart';
import 'avisos_caja.dart';
import 'caja_contextual_panel.dart';
import 'caja_disposiciones.dart';
import 'hoja_gasto_caja.dart';
import 'hoja_gastos_de_hoy.dart';
import 'mostrar_hoja_producto.dart';
import 'preparacion_catalogo_host.dart';
import 'ticket_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// CajaFlow
// ═════════════════════════════════════════════════════════════════════════
// La pantalla «Hoy» de Caja: crea los providers (catálogo, venta, día, gasto
// y preparación del catálogo), los cierra al salir y une las acciones:
//
//   tocar un producto → su hoja → se agrega a la venta
//   Cobrar            → registra, baja el stock de la lista EN MEMORIA (0
//                       lecturas) y avisa con «Anular» 8 segundos
//   Gasto             → su hoja → se guarda y avisa con «Anular»
//   «Gastos» del día  → «Gastos de hoy» → Corregir (el formulario lleno: el
//                       viejo queda anulado y nace el correcto) o anular
//   ¿Cómo funciona?   → la ayuda
//
// Lecturas: 20 del catálogo y 1 del día al abrir; el día escucha UN documento
// y se cierra al salir. Las formas de pago y las zonas son las de CADA
// negocio: llegan ya convertidas a enteros.
// ═════════════════════════════════════════════════════════════════════════
class CajaFlow extends StatefulWidget {
  const CajaFlow({
    super.key,
    required this.negocioId,
    required this.rubro,
    required this.dependencias,
    this.categorias = const [],
    this.opcionesPago = const [],
    this.zonas = const [],
    this.reloj,
  });

  final String negocioId;
  final String rubro;
  final CajaDependencies dependencias;
  final List<String> categorias;
  final List<OpcionPagoCaja> opcionesPago;
  final List<ZonaCaja> zonas;
  final DateTime Function()? reloj;

  @override
  State<CajaFlow> createState() => _CajaFlowState();
}

class _CajaFlowState extends State<CajaFlow> {
  late final CatalogoCajaProvider _catalogo;
  late final VentaCajaProvider _venta;
  late final DiaCajaProvider _dia;
  late final GastoCajaProvider _gasto;
  late final PreparacionCatalogoProvider _preparacion;

  @override
  void initState() {
    super.initState();
    final d = widget.dependencias;
    final id = widget.negocioId;
    _catalogo = d.crearCatalogo(id)..iniciar();
    _venta = d.crearVenta(
      id,
      opcionesPago: widget.opcionesPago,
      zonas: widget.zonas,
    );
    _dia = d.crearDia(id, reloj: widget.reloj)..iniciar();
    _gasto = d.crearGasto(id, opcionesPago: widget.opcionesPago);
    _preparacion = d.crearPreparacion(id);
  }

  @override
  void dispose() {
    _catalogo.dispose();
    _venta.dispose();
    _dia.dispose();
    _gasto.dispose();
    _preparacion.dispose();
    super.dispose();
  }

  /// La venta está a la vista en un panel (no hace falta abrir la hoja). Lo
  /// calcula la disposición con el espacio REAL que tiene Caja.
  bool _ventaAlLado = false;

  Future<void> _elegir(Producto producto) async {
    final accion = await mostrarHojaProducto(
      context,
      producto: producto,
      onConfirmar: (seleccion, _) => _venta.agregarProducto(
        producto,
        cantidad: seleccion.cantidad,
        modeloId: seleccion.modeloId,
        filaId: seleccion.filaId,
        extrasIds: seleccion.extrasIds.toList(),
      ),
    );
    if (!mounted) return;
    if (accion == AccionHojaProducto.agregarYCobrar && !_ventaAlLado) {
      await _verVenta();
    }
  }

  Future<void> _verVenta() async {
    final cobrar = await mostrarTicketCaja(
      context,
      provider: _venta,
      rubro: widget.rubro,
    );
    if (cobrar == true && mounted) await _cobrar();
  }

  Future<void> _cobrar() async {
    // Un delivery sigue su camino en Pedidos: desde Caja no se anula.
    final eraDelivery = _venta.esDelivery;
    final r = await _venta.cobrar();
    if (!mounted) return;
    if (!r.registrada) {
      avisarCaja(context, r.mensaje, error: true);
      return;
    }
    _catalogo.ajustarStock(r.descuentos);
    _dia.revisarDia();
    final sePuedeAnular =
        r.tipo == TipoCobroCaja.exito && !eraDelivery && r.pedidoId.isNotEmpty;
    avisarCaja(
      context,
      eraDelivery ? '${r.mensaje} · Sigue en Pedidos' : r.mensaje,
      onAccion: sePuedeAnular ? () => _anularVenta(r) : null,
    );
  }

  Future<void> _anularVenta(ResultadoCobroCaja cobro) async {
    final r = await _venta.anularVenta(cobro.pedidoId);
    if (!mounted) return;
    // Devuelve a la lista exactamente lo que esa venta descontó.
    if (r.ok) _catalogo.ajustarStock(cobro.descuentos, devolver: true);
    avisarCaja(context, r.mensaje, error: !r.ok);
  }

  Future<void> _anotarGasto() async {
    final r = await mostrarHojaGasto(context, provider: _gasto);
    if (r == null || !mounted) return;
    _dia.revisarDia();
    avisarCaja(
      context,
      r.mensaje,
      onAccion: r.gastoId.isEmpty ? null : () => _anularGasto(r.gastoId),
    );
  }

  Future<void> _anularGasto(String gastoId) async {
    final r = await _gasto.anular(gastoId);
    if (!mounted) return;
    avisarCaja(context, r.mensaje, error: !r.ok);
  }

  /// «Gastos de hoy»: se lee una vez al abrir (1 lectura por gasto, tope de
  /// 20) y se cierra al salir. Los números del día se arreglan solos.
  Future<void> _verGastos() async {
    final lista = widget.dependencias.crearGastosDeHoy(widget.negocioId)
      ..cargar();
    await mostrarHojaGastosDeHoy(
      context,
      provider: lista,
      opcionesPago: widget.opcionesPago,
      onCorregir: (g) => _corregirGasto(lista, g),
    );
    lista.dispose();
  }

  Future<void> _corregirGasto(GastosDeHoyProvider lista, GastoCaja g) async {
    final form = widget.dependencias.crearCorreccionGasto(
      widget.negocioId,
      original: g,
      opcionesPago: widget.opcionesPago,
    );
    final r = await mostrarHojaGasto(context, provider: form);
    form.dispose();
    if (r == null) return;
    lista.aplicar(g.id, r);
    _dia.revisarDia();
  }

  @override
  Widget build(BuildContext context) {
    return PreparacionCatalogoHost(
      provider: _preparacion,
      alQuedarLista: _catalogo.reiniciar,
      alCambiarBloqueo: _venta.bloquearVentas,
      child: LayoutBuilder(
        builder: (context, c) {
          _ventaAlLado = DisposicionCaja.ventaAlLado(c.maxWidth, c.maxHeight);
          return DisposicionCaja(
            catalogo: _catalogo,
            venta: _venta,
            dia: _dia,
            preparacion: _preparacion,
            rubro: widget.rubro,
            categorias: widget.categorias,
            onElegir: _elegir,
            onCobrar: _cobrar,
            onVerVenta: _verVenta,
            onGasto: _anotarGasto,
            onVerGastos: _verGastos,
            onAyuda: () => mostrarAyudaCaja(context),
          );
        },
      ),
    );
  }
}
