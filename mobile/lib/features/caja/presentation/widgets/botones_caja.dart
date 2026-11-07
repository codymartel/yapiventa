import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// El botón principal de Caja: relleno azul, de 48 px de alto y a todo el
/// ancho. Uno por pantalla (la acción que se espera). Sin [onTap] queda
/// apagado.
class BotonPrincipalCaja extends StatelessWidget {
  const BotonPrincipalCaja({super.key, required this.texto, this.onTap});

  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
      ),
      onPressed: onTap,
      child: Text(texto),
    );
  }
}

/// El botón secundario de Caja: con borde, de 48 px de alto y a todo el ancho
/// («Más tarde», «Agregar y seguir», «Ver más»). Sin [onTap] queda apagado.
class BotonSecundarioCaja extends StatelessWidget {
  const BotonSecundarioCaja({super.key, required this.texto, this.onTap});

  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.azulTexto,
        side: const BorderSide(color: AppColors.hint),
      ),
      onPressed: onTap,
      child: Text(texto),
    );
  }
}
