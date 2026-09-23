import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RubroContextualPanel extends StatelessWidget {
  final String rubro;

  const RubroContextualPanel({super.key, this.rubro = 'Otros'});

  @override
  Widget build(BuildContext context) {
    final contenido = _contenidoPara(rubro);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 320;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SeccionRubro(
              icono: Icons.check_circle_outline,
              titulo: 'Sirve para',
              contenido: contenido.$1,
              compacto: compacto,
            ),
            const SizedBox(height: 12),
            _SeccionRubro(
              icono: Icons.straighten_outlined,
              titulo: 'Medidas sugeridas',
              contenido: contenido.$2,
              compacto: compacto,
            ),
            const SizedBox(height: 12),
            _SeccionRubro(
              icono: Icons.info_outline,
              titulo: 'No incluye',
              contenido: contenido.$3,
              compacto: compacto,
            ),
            const SizedBox(height: 14),
            Text(
              'YapiVenta es un gestor de catálogo, productos y tienda web. '
              'No es un sistema contable, tributario, médico ni logístico.',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: compacto ? 12 : 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  (String, String, String) _contenidoPara(String valor) {
    final rubroCompatible = valor == 'Farmacia' || valor == 'Ferretería'
        ? 'Otros'
        : valor;
    return switch (rubroCompatible) {
      'Bodega' => (
        'Organizar productos vendidos por unidad, peso, volumen o '
            'presentación, controlar su disponibilidad y prepararlos para el '
            'catálogo web.',
        'Unidad, docena, gramos, kilogramos, mililitros, litros, botellas, '
            'bolsas, cajas y paquetes.',
        'No reemplaza una caja registradora fiscal, no emite comprobantes '
            'electrónicos y no calcula automáticamente rutas o distancias de '
            'delivery.',
      ),
      'Restaurante' => (
        'Organizar una carta de comidas y bebidas, manejar precios, porciones '
            'y productos disponibles para pedidos.',
        'Unidad, porción, media porción, ¼ de porción, ⅛ de porción, vaso, '
            'botella, jarra, plato y combo.',
        'No administra mesas, comandas de cocina, recetas, costos de '
            'ingredientes ni reservas del local.',
      ),
      'Ropa' => (
        'Crear un catálogo visual de prendas y controlar productos vendidos '
            'por unidad.',
        'Unidad, par, conjunto y paquete.',
        'Esta fase todavía no administra existencias independientes por talla '
            'y color. Las variantes se implementarán en Productos.',
      ),
      'Accesorios y regalos' => (
        'Organizar accesorios, regalos y artículos vendidos individualmente o '
            'en conjuntos.',
        'Unidad, par, juego, set, paquete, caja y bolsa.',
        'No administra fabricación personalizada, órdenes de producción ni '
            'stock por variantes en esta fase.',
      ),
      'Belleza y cuidado personal' => (
        'Organizar productos de belleza vendidos por unidad, peso, volumen o '
            'presentación.',
        'Unidad, gramos, kilogramos, mililitros, litros, frascos, botellas, '
            'potes, tubos y sachets.',
        'No realiza diagnósticos, recetas médicas ni control sanitario de '
            'medicamentos.',
      ),
      _ => (
        'Crear un catálogo básico de productos que puedan venderse con las '
            'funciones generales disponibles.',
        'Unidad y presentaciones comerciales básicas.',
        'No garantiza procesos especializados para todos los tipos de '
            'negocio. Solo ofrece catálogo, disponibilidad y las funciones '
            'generales de YapiVenta.',
      ),
    };
  }
}

class _SeccionRubro extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String contenido;
  final bool compacto;

  const _SeccionRubro({
    required this.icono,
    required this.titulo,
    required this.contenido,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icono, color: AppColors.blueLt, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: compacto ? 13 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contenido,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: compacto ? 11 : 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
