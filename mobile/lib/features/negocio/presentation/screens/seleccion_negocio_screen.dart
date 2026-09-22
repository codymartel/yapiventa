import 'package:flutter/material.dart';

import '../widgets/seleccion_negocio_content.dart';
import '../widgets/seleccion_negocio_flow.dart';

class SeleccionNegocioScreen extends StatelessWidget {
  final String rubroInicial;
  final Future<bool> Function(String rubro) onTipoSeleccionado;
  final VoidCallback onVolverDashboard;

  const SeleccionNegocioScreen({
    super.key,
    this.rubroInicial = '',
    required this.onTipoSeleccionado,
    required this.onVolverDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeleccionNegocioContent.fondo,
      body: SafeArea(
        child: SeleccionNegocioFlow(
          rubroInicial: rubroInicial,
          onTipoSeleccionado: onTipoSeleccionado,
          onCompletado: onVolverDashboard,
          onVolver: onVolverDashboard,
        ),
      ),
    );
  }
}
