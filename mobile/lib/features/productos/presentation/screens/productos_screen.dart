// ═════════════════════════════════════════════════════════════════════════
// ProductosScreen
// ═════════════════════════════════════════════════════════════════════════
// Placeholder temporal de Productos — se reemplaza cuando migres la
// pantalla real de productos desde Kotlin. Vive aquí (en
// presentation/screens/productos_screen.dart) y su única responsabilidad
// hoy es darle un destino navegable a la ruta '/productos' de main.dart.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ProductosScreen extends StatelessWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Center(
        child: Text(
          'Productos (pendiente de migrar)',
          style: TextStyle(color: AppColors.texto, fontSize: 18),
        ),
      ),
    );
  }
}