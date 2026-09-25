import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../negocio/presentation/providers/configuracion_negocio_provider.dart';

/// Ayuda contextual de la fase de configuración del negocio.
///
/// El contenido depende SOLO del paso actual del wizard
/// ([ConfiguracionNegocioProvider.pasoActual]), de modo que editar campos o
/// cambiar el prefijo telefónico no altera la ayuda: solo cambia al avanzar
/// o retroceder entre pasos.
///
/// Reutiliza el [ConfiguracionNegocioProvider] existente; no crea providers,
/// no consulta repositorios ni Firebase, no navega y no escribe nada.
class ConfiguracionContextualPanel extends StatelessWidget {
  final ConfiguracionNegocioProvider provider;

  const ConfiguracionContextualPanel({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final movil = MediaQuery.sizeOf(context).width < 600;
        return _ContenidoPaso(
          paso: provider.pasoActual,
          catalogoPestana: provider.catalogoPestana,
          movil: movil,
        );
      },
    );
  }
}

class _ContenidoPaso extends StatelessWidget {
  final int paso;
  final int catalogoPestana;
  final bool movil;

  const _ContenidoPaso({
    required this.paso,
    required this.catalogoPestana,
    required this.movil,
  });

  @override
  Widget build(BuildContext context) {
    final datos = paso == 1
        ? _datosDeCatalogo(catalogoPestana)
        : _datosDelPaso(paso);
    return Column(
      key: const Key('configuracion-contextual-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EncabezadoPaso(
          titulo: datos.$1,
          subtitulo: datos.$2,
          paso: paso,
          movil: movil,
        ),
        const SizedBox(height: 12),
        for (final tarjeta in datos.$3) ...[
          _TarjetaAyuda(
            icono: tarjeta.$1,
            titulo: tarjeta.$2,
            contenido: tarjeta.$3,
            movil: movil,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // Ayuda del paso Catálogo según la pestaña interna activa: cada pestaña
  // explica su propia área del catálogo seguro (presentaciones + medidas).
  (String, String, List<(IconData, String, String)>) _datosDeCatalogo(
    int pestana,
  ) {
    final tarjeta = switch (pestana) {
      1 => (
        Icons.inventory_2_outlined,
        'Presentaciones',
        'La presentación es el envase o la pieza completa que vendes: '
            'el formato describe su contenido. "Botella 650 ml" descuenta '
            'una botella de 650 ml en el futuro.',
      ),
      2 => (
        Icons.square_foot_outlined,
        'Medidas',
        'Vender por medida entrega partes de un stock mayor: defines un '
            'mínimo, un incremento y si se pide por cantidad o por soles. '
            '"600 ml a granel" son exactamente 600 ml.',
      ),
      _ => (
        Icons.category_outlined,
        'Categorías',
        'Las categorías organizan tus productos y agrupan '
            'lo que verán tus clientes.',
      ),
    };
    return ('Catálogo', 'Cómo se organizan tus productos.', [tarjeta]);
  }

  (String, String, List<(IconData, String, String)>) _datosDelPaso(int paso) {
    return switch (paso) {
      0 => (
        'Negocio',
        'Datos que identifican tu negocio.',
        [
          (
            Icons.storefront_outlined,
            'Qué registras',
            'Nombre, WhatsApp y dirección de tu negocio, '
                'más la referencia de tu local.',
          ),
          (
            Icons.phone_iphone_outlined,
            'Prefijo telefónico',
            'El prefijo solo indica el país del número. '
                'Cambiar de país no afecta el resto de tus datos.',
          ),
        ],
      ),
      1 => (
        'Catálogo',
        'Cómo se organizan tus productos.',
        [
          (
            Icons.category_outlined,
            'Categorías',
            'Las categorías organizan tus productos y agrupan '
                'lo que verán tus clientes.',
          ),
          (
            Icons.straighten_outlined,
            'Unidades',
            'Las unidades activas serán las opciones disponibles '
                'al crear productos.',
          ),
          (
            Icons.calculate_outlined,
            'Sin cálculos automáticos',
            'Todavía no se calculan fracciones ni se convierten '
                'unidades automáticamente: cada unidad se usa tal '
                'como la defines.',
          ),
        ],
      ),
      2 => (
        'Logística',
        'Cómo entregas tus productos.',
        [
          (
            Icons.local_shipping_outlined,
            'Delivery',
            'Delivery, zonas, costo fijo y horarios de atención '
                'de tu negocio.',
          ),
          (
            Icons.location_off_outlined,
            'Sin GPS automático',
            'YapiVenta no calcula distancias ni usa GPS '
                'automáticamente: define tú las zonas y sus costos.',
          ),
        ],
      ),
      _ => (
        'Pagos',
        'Cómo cobras a tus clientes.',
        [
          (
            Icons.currency_exchange_outlined,
            'Métodos de pago',
            'Define los métodos que el negocio acepta, '
                'como Efectivo, Yape/Plin o transferencia.',
          ),
          (
            Icons.info_outline,
            'Sin verificación automática',
            'YapiVenta no verifica depósitos automáticamente: '
                'confirma tú cada pago.',
          ),
        ],
      ),
    };
  }
}

class _EncabezadoPaso extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final int paso;
  final bool movil;

  const _EncabezadoPaso({
    required this.titulo,
    required this.subtitulo,
    required this.paso,
    required this.movil,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso ${paso + 1} de ${ConfiguracionNegocioProvider.totalPasos}',
            style: TextStyle(
              color: AppColors.blueLt,
              fontSize: movil ? 11 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: TextStyle(
              color: AppColors.texto,
              fontSize: movil ? 16 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitulo,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: movil ? 12 : 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAyuda extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String contenido;
  final bool movil;

  const _TarjetaAyuda({
    required this.icono,
    required this.titulo,
    required this.contenido,
    required this.movil,
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
                    fontSize: movil ? 14 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contenido,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: movil ? 12 : 11,
                    height: 1.35,
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