// ═════════════════════════════════════════════════════════════════════════
// PedidosScreen
// ═════════════════════════════════════════════════════════════════════════
// Pantalla de pedidos. Solo el andamiaje de navegación (Scaffold + AppBar +
// SafeArea), igual que `ProductosScreen`; todo lo demás vive en `PedidosFlow`
// para poder reutilizarlo dentro del tablero.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:mobile/features/negocio/domain/models/pais_telefono.dart';

import '../../../../core/theme/app_colors.dart';
import '../../pedidos_dependencies.dart';
import '../widgets/pedidos_flow.dart';

class PedidosScreen extends StatelessWidget {
  const PedidosScreen({
    super.key,
    required this.negocioId,
    required this.dependencias,
    this.pais,
    this.onVolver,
  });

  final String negocioId;
  final PedidosDependencies dependencias;
  final PaisTelefono? pais;
  final VoidCallback? onVolver;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.superficie,
        foregroundColor: AppColors.texto,
        automaticallyImplyLeading: false,
        title: const Text('Pedidos'),
        leading: onVolver == null
            ? null
            : IconButton(
                tooltip: 'Volver',
                onPressed: onVolver,
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: SafeArea(
        child: PedidosFlow(
          negocioId: negocioId,
          dependencias: dependencias,
          pais: pais,
        ),
      ),
    );
  }
}
