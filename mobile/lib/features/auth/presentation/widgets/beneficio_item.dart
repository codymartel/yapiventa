import 'package:flutter/material.dart';

/// Migración directa de tu @Composable BeneficioItem(icono, texto).
/// Un StatelessWidget en Flutter es el equivalente exacto a un @Composable
/// sin estado en Kotlin — solo recibe datos y dibuja.
class BeneficioItem extends StatelessWidget {
  final String icono;
  final String texto;

  const BeneficioItem({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(icono, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 14),
          Text(
            texto,
            style: const TextStyle(color: Color(0xFFC8D4E8), fontSize: 14),
          ),
        ],
      ),
    );
  }
}