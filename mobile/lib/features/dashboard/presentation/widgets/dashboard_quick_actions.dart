import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardQuickActions extends StatelessWidget {
  final VoidCallback onAgregarProducto;
  final VoidCallback onActualizarStock;
  final VoidCallback onVerPedidos;
  final VoidCallback onResponderQueja;

  const DashboardQuickActions({
    super.key,
    required this.onAgregarProducto,
    required this.onActualizarStock,
    required this.onVerPedidos,
    required this.onResponderQueja,
  });

  @override
  Widget build(BuildContext context) {
    final acciones = [
      _Accion(
        texto: 'Agregar producto',
        icono: Icons.add_box_outlined,
        color: const Color(0xFF4E8BFF),
        onTap: onAgregarProducto,
      ),
      _Accion(
        texto: 'Actualizar stock',
        icono: Icons.inventory_outlined,
        color: const Color(0xFF8D7CFF),
        onTap: onActualizarStock,
      ),
      _Accion(
        texto: 'Ver pedidos',
        icono: Icons.receipt_long_outlined,
        color: const Color(0xFF35C59A),
        onTap: onVerPedidos,
      ),
      _Accion(
        texto: 'Responder queja',
        icono: Icons.mark_chat_unread_outlined,
        color: const Color(0xFFFF718B),
        onTap: onResponderQueja,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones rápidas',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Atajos para el trabajo diario',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnas = constraints.maxWidth >= 700 ? 4 : 2;
              const espacio = 10.0;
              final ancho =
                  (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
              return Wrap(
                spacing: espacio,
                runSpacing: espacio,
                children: [
                  for (final accion in acciones)
                    SizedBox(
                      width: ancho,
                      child: _AccionButton(accion: accion),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Accion {
  final String texto;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  const _Accion({
    required this.texto,
    required this.icono,
    required this.color,
    required this.onTap,
  });
}

class _AccionButton extends StatelessWidget {
  final _Accion accion;

  const _AccionButton({required this.accion});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: accion.onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(accion.icono, color: accion.color, size: 22),
              const SizedBox(height: 13),
              Text(
                accion.texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
