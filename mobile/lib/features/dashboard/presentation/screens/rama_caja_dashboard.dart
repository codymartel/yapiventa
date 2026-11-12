import 'package:flutter/material.dart';

import '../../../caja/application/services/opciones_caja_desde_negocio.dart';
import '../../../caja/caja_dependencies.dart';
import '../../../caja/presentation/widgets/caja_flow.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';

/// Caja dentro del tablero (el ítem «Ventas» del menú). Le pasa a `CajaFlow`
/// lo que configuró el negocio: su rubro, sus categorías, sus formas de pago
/// activas y sus zonas de delivery. Todo sale de la configuración ya cargada:
/// conectar no agrega lecturas.
///
/// No se deja viva por detrás: al salir se cierran sus escuchas (ahorra
/// lecturas) y al volver se abre de nuevo, igual que Pedidos. Las formas de
/// pago y las zonas se toman al abrir: un cambio en Configuración se ve la
/// próxima vez que se entra (nunca a mitad de una venta).
class RamaCajaDashboard extends StatefulWidget {
  const RamaCajaDashboard({
    super.key,
    required this.negocioId,
    required this.progreso,
    this.dependencias,
  });

  final String negocioId;
  final ProgresoConfiguracion progreso;

  /// Para pruebas. En la app se arman las de producción una sola vez.
  final CajaDependencies? dependencias;

  @override
  State<RamaCajaDashboard> createState() => _RamaCajaDashboardState();
}

class _RamaCajaDashboardState extends State<RamaCajaDashboard> {
  late final CajaDependencies _dependencias =
      widget.dependencias ?? CajaDependencies.production();

  @override
  Widget build(BuildContext context) {
    final catalogo = widget.progreso.catalogo;
    final negocio = catalogo.configuracionInicial;
    return CajaFlow(
      negocioId: widget.negocioId,
      rubro: catalogo.rubro,
      categorias: catalogo.categorias,
      opcionesPago: OpcionesCajaDesdeNegocio.pagos(negocio),
      zonas: OpcionesCajaDesdeNegocio.zonas(negocio),
      dependencias: _dependencias,
    );
  }
}
