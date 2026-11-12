import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/models/producto.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/tamanos_caja.dart';
import '../../application/services/textos_dia_caja.dart';
import '../providers/catalogo_caja_provider.dart';
import '../providers/dia_caja_provider.dart';
import '../providers/preparacion_catalogo_provider.dart';
import '../providers/venta_caja_provider.dart';
import 'aviso_catalogo_sin_preparar.dart';
import 'barra_dia_caja.dart';
import 'botones_caja.dart';
import 'caja_vista_tv.dart';
import 'catalogo_caja_vista.dart';
import 'ticket_caja.dart';

/// Acomoda Caja según el espacio (ver `TamanosCaja`):
///
///   celular            lista arriba y «Ver venta» abajo (la venta va en hoja)
///   tableta y celular  lista a la izquierda y la venta fija a la derecha
///   de lado
///   PC                 tablero de 6 números, lista y la venta a la derecha
///   TV                 solo se mira el día
///
/// Con poco alto (de lado, ventana bajita o teclado abierto) los números del
/// día pasan a UNA fila dentro de la barra de arriba. Con muy poco alto (de
/// lado y con teclado) queda solo la lista con su buscador: nada se aplasta.
/// No guarda estado: recibe los providers y avisa las acciones.
class DisposicionCaja extends StatelessWidget {
  const DisposicionCaja({
    super.key,
    required this.catalogo,
    required this.venta,
    required this.dia,
    required this.preparacion,
    required this.rubro,
    required this.categorias,
    required this.onElegir,
    required this.onCobrar,
    required this.onVerVenta,
    required this.onGasto,
    required this.onAyuda,
  });

  final CatalogoCajaProvider catalogo;
  final VentaCajaProvider venta;
  final DiaCajaProvider dia;
  final PreparacionCatalogoProvider preparacion;
  final String rubro;
  final List<String> categorias;
  final ValueChanged<Producto> onElegir;
  final VoidCallback onCobrar;
  final VoidCallback onVerVenta;
  final VoidCallback onGasto;
  final VoidCallback onAyuda;

  /// Ancho mínimo para poner la venta al costado en un celular de lado (la
  /// lista necesita unos 340 px para su buscador y sus filtros).
  static const double _anchoLadoALado = 640;

  /// Con menos alto que esto solo queda la lista con su buscador.
  static const double _altoSoloLista = 260;

  /// La venta se ve en un panel al costado (tableta, PC o un celular de lado
  /// con ancho suficiente). Si no, se abre en una hoja con «Ver venta».
  static bool ventaAlLado(double ancho, double alto) {
    final forma = TamanosCaja.forma(ancho);
    if (forma == FormaCaja.tv) return false;
    return forma.ticketAlLado ||
        (TamanosCaja.esBajo(alto) && ancho >= _anchoLadoALado);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth;
        final alto = c.maxHeight;
        final forma = TamanosCaja.forma(ancho);
        if (forma == FormaCaja.tv) return CajaVistaTv(provider: dia);

        final bajo = TamanosCaja.esBajo(alto);
        final soloLista = alto < _altoSoloLista;
        final alLado = ventaAlLado(ancho, alto);

        final lista = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Con poco alto los números van en la barra de arriba.
              if (!bajo) ...[
                BarraDiaCaja(
                  provider: dia,
                  estilo: forma == FormaCaja.pc
                      ? EstiloDiaCaja.tablero
                      : EstiloDiaCaja.tarjetas,
                ),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: CatalogoCajaVista(
                  provider: catalogo,
                  rubro: rubro,
                  categorias: categorias,
                  onElegir: onElegir,
                  cabecera: bajo
                      ? null
                      : AvisoCatalogoSinPreparar(provider: preparacion),
                ),
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!soloLista)
              _Cabecera(
                dia: dia,
                conNumeros: bajo,
                onGasto: onGasto,
                onAyuda: onAyuda,
              ),
            Expanded(
              child: alLado
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: lista),
                        const VerticalDivider(width: 1, color: AppColors.dim),
                        SizedBox(
                          width: forma == FormaCaja.pc
                              ? TamanosCaja.anchoTicketPc
                              : TamanosCaja.anchoTicketTableta,
                          child: Material(
                            color: AppColors.superficie,
                            child: TicketCajaPanel(
                              provider: venta,
                              rubro: rubro,
                              onCobrar: onCobrar,
                            ),
                          ),
                        ),
                      ],
                    )
                  : lista,
            ),
            if (!alLado && !soloLista)
              _BotonVerVenta(
                venta: venta,
                onVerVenta: onVerVenta,
                compacto: bajo,
              ),
          ],
        );
      },
    );
  }
}

/// La barra de arriba: el estado de la conexión, la ayuda y «Gasto». Con
/// poco alto ([conNumeros]) lleva los números del día en una fila, en lugar
/// del estado, para no gastar otra línea.
class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.dia,
    required this.conNumeros,
    required this.onGasto,
    required this.onAyuda,
  });

  final DiaCajaProvider dia;
  final bool conNumeros;
  final VoidCallback onGasto;
  final VoidCallback onAyuda;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: conNumeros
                ? BarraDiaCaja(provider: dia, estilo: EstiloDiaCaja.fila)
                : ListenableBuilder(
                    listenable: dia,
                    builder: (context, _) {
                      final (texto, color) = dia.error
                          ? ('● Sin conexión', AppColors.aviso)
                          : dia.enVivo
                          ? ('● En vivo', AppColors.ok)
                          : ('Cargando el día…', AppColors.muted);
                      return Text(
                        texto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
          ),
          IconButton(
            tooltip: '¿Cómo funciona?',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.help_outline, color: AppColors.muted),
            onPressed: onAyuda,
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: AppColors.azulTexto,
              side: const BorderSide(color: AppColors.hint),
              shape: const StadiumBorder(),
            ),
            onPressed: onGasto,
            icon: const Icon(Icons.north_east, size: 18),
            label: const Text('Gasto'),
          ),
        ],
      ),
    );
  }
}

/// El botón fijo de abajo en celular: abre la venta. Dice cuántos productos
/// lleva y el total; sin productos queda apagado y lo explica.
class _BotonVerVenta extends StatelessWidget {
  const _BotonVerVenta({
    required this.venta,
    required this.onVerVenta,
    this.compacto = false,
  });

  final VentaCajaProvider venta;
  final VoidCallback onVerVenta;

  /// Con poco alto: menos aire alrededor (el botón sigue de 48 px).
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          compacto ? 4 : 8,
          16,
          compacto ? 6 : 12,
        ),
        child: ListenableBuilder(
          listenable: venta,
          builder: (context, _) {
            final n = venta.carrito.lineas.length;
            if (n == 0) {
              return const BotonPrincipalCaja(
                texto: 'Agrega productos para vender',
              );
            }
            final productos = n == 1 ? '1 producto' : '$n productos';
            return BotonPrincipalCaja(
              texto:
                  'Ver venta · $productos · '
                  '${TextosDiaCaja.plata(venta.venta.totalCentavos)}',
              onTap: onVerVenta,
            );
          },
        ),
      ),
    );
  }
}
