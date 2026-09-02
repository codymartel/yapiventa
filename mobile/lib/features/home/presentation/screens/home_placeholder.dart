import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Placeholder temporal de Home — se reemplaza cuando se migre
/// home_screen.dart. Definido una sola vez para que todos los caminos
/// que llegan a "Home" usen la misma pantalla.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Center(
        child: Text(
          '¡Bienvenido! (Home pendiente de migrar)',
          style: TextStyle(color: AppColors.texto, fontSize: 18),
        ),
      ),
    );
  }
}
