// ═════════════════════════════════════════════════════════════════════════
// ProductosScreen
// ═════════════════════════════════════════════════════════════════════════
// Pantalla de productos. Wrapper de ruta (patrón ConfiguracionNegocioScreen):
// conserva únicamente el andamiaje de navegación (Scaffold + AppBar +
// SafeArea); la creación de providers, la carga inicial, los diálogos y el
// FAB móvil viven en ProductosFlow (widgets/productos_flow.dart), de modo
// que el mismo flujo pueda reutilizarse dentro del dashboard.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../negocio/catalogo_negocio_dependencies.dart';
import '../../../negocio/domain/models/catalogo_negocio.dart';
import '../../productos_dependencies.dart';
import '../widgets/productos_flow.dart';

class ProductosScreen extends StatelessWidget {
  final String uid;
  final String? negocioId;
  final CatalogoNegocio catalogoInicial;
  final VoidCallback? onVolver;
  final ValueChanged<String>? onElegirPlantilla;
  final VoidCallback? onProgressChanged;
  final ProductosDependencies? productosDependencies;
  final CatalogoNegocioDependencies? catalogoDependencies;

  const ProductosScreen({
    super.key,
    required this.uid,
    required this.negocioId,
    required this.catalogoInicial,
    this.onVolver,
    this.onElegirPlantilla,
    this.onProgressChanged,
    this.productosDependencies,
    this.catalogoDependencies,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: AppColors.superficie,
        foregroundColor: AppColors.texto,
        automaticallyImplyLeading: false,
        title: const Text('Productos'),
        leading: onVolver == null
            ? null
            : IconButton(
                tooltip: 'Volver',
                onPressed: onVolver,
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: SafeArea(
        child: ProductosFlow(
          uid: uid,
          negocioId: negocioId,
          catalogoInicial: catalogoInicial,
          onVolver: onVolver,
          onElegirPlantilla: onElegirPlantilla,
          onProgressChanged: onProgressChanged,
          productosDependencies: productosDependencies,
          catalogoDependencies: catalogoDependencies,
        ),
      ),
    );
  }
}
