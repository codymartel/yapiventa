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
/// Visualmente es UNA sola tarjeta: el encabezado "Paso N de 4 / Negocio"
/// desapareció porque el stepper ya indica la posición, así que la ayuda se
/// lee como un bloque continuo en vez de una pila de cajas.
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
        final compacto = MediaQuery.sizeOf(context).width < 600;
        return _ContenidoPaso(
          paso: provider.pasoActual,
          catalogoPestana: provider.catalogoPestana,
          compacto: compacto,
        );
      },
    );
  }
}

/// Bloques de ayuda de un paso. Solo presentación: textos fijos por paso.
class _Contenido {
  final String titulo;
  final String? parrafo;
  final String? listaTitulo;
  final List<String> lista;
  final List<({IconData icono, String titulo, String texto})> bloques;
  final String? cierre;

  const _Contenido({
    required this.titulo,
    this.parrafo,
    this.listaTitulo,
    this.lista = const [],
    this.bloques = const [],
    this.cierre,
  });
}

class _ContenidoPaso extends StatelessWidget {
  final int paso;
  final int catalogoPestana;
  final bool compacto;

  const _ContenidoPaso({
    required this.paso,
    required this.catalogoPestana,
    required this.compacto,
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
        Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.bordeSutil),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Encabezado(compacto: compacto),
              const SizedBox(height: 11),
              const _Separador(),
              const SizedBox(height: 11),
              Text(
                datos.titulo,
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (datos.parrafo != null) ...[
                const SizedBox(height: 6),
                Text(
                  datos.parrafo!,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: compacto ? 12.5 : 13,
                    height: 1.4,
                  ),
                ),
              ],
              if (datos.listaTitulo != null) ...[
                const SizedBox(height: 12),
                Text(
                  datos.listaTitulo!,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: compacto ? 12.5 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                for (final item in datos.lista) _ItemMarcado(texto: item),
              ],
              for (final bloque in datos.bloques) ...[
                const SizedBox(height: 11),
                const _Separador(),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Icon(bloque.icono, size: 14, color: AppColors.blueLt),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        bloque.titulo,
                        style: TextStyle(
                          color: AppColors.texto,
                          fontSize: compacto ? 12.5 : 13.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bloque.texto,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: compacto ? 12.5 : 13,
                    height: 1.4,
                  ),
                ),
              ],
              if (datos.cierre != null) ...[
                const SizedBox(height: 8),
                Text(
                  datos.cierre!,
                  style: TextStyle(
                    color: AppColors.dim,
                    fontSize: compacto ? 12 : 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Ayuda del paso Catálogo según la pestaña interna activa: cada pestaña
  // explica su propia área del catálogo seguro (presentaciones + medidas).
  _Contenido _datosDeCatalogo(int pestana) {
    final bloque = switch (pestana) {
      1 => (
        icono: Icons.inventory_2_outlined,
        titulo: 'Presentaciones',
        texto: 'La presentación es el envase o la pieza completa que vendes: '
            'el formato describe su contenido. "Botella 650 ml" descuenta '
            'una botella de 650 ml en el futuro.',
      ),
      2 => (
        icono: Icons.square_foot_outlined,
        titulo: 'Medidas',
        texto: 'Vender por medida entrega partes de un stock mayor: defines un '
            'mínimo, un incremento y si se pide por cantidad o por soles. '
            '"600 ml a granel" son exactamente 600 ml.',
      ),
      _ => (
        icono: Icons.category_outlined,
        titulo: 'Categorías',
        texto: 'Las categorías organizan tus productos y agrupan '
            'lo que verán tus clientes.',
      ),
    };
    return _Contenido(
      titulo: 'Cómo se organizan tus productos.',
      bloques: [bloque],
    );
  }

  _Contenido _datosDelPaso(int paso) {
    return switch (paso) {
      0 => const _Contenido(
        titulo: '¿Dónde se usará esta información?',
        parrafo:
            'Estos datos aparecerán en tu tienda web y permitirán que tus '
            'clientes puedan contactarte.',
        listaTitulo: 'Aquí registrarás:',
        lista: [
          'Nombre del negocio',
          'WhatsApp',
          'Dirección',
          'Referencia',
        ],
        bloques: [
          (
            icono: Icons.phone_iphone_outlined,
            titulo: 'Prefijo telefónico',
            texto: '+51 corresponde a Perú.',
          ),
        ],
        cierre:
            'El prefijo solo indica el país del número. Cambiar de país no '
            'afecta el resto de tus datos.',
      ),
      1 => const _Contenido(
        titulo: 'Cómo se organizan tus productos.',
        bloques: [
          (
            icono: Icons.category_outlined,
            titulo: 'Categorías',
            texto: 'Las categorías organizan tus productos y agrupan '
                'lo que verán tus clientes.',
          ),
          (
            icono: Icons.straighten_outlined,
            titulo: 'Unidades',
            texto: 'Las unidades activas serán las opciones disponibles '
                'al crear productos.',
          ),
          (
            icono: Icons.calculate_outlined,
            titulo: 'Sin cálculos automáticos',
            texto: 'Todavía no se calculan fracciones ni se convierten '
                'unidades automáticamente: cada unidad se usa tal '
                'como la defines.',
          ),
        ],
      ),
      2 => const _Contenido(
        titulo: 'Cómo entregas tus productos.',
        bloques: [
          (
            icono: Icons.local_shipping_outlined,
            titulo: 'Delivery',
            texto: 'Delivery, zonas, costo fijo y horarios de atención '
                'de tu negocio.',
          ),
          (
            icono: Icons.location_off_outlined,
            titulo: 'Sin GPS automático',
            texto: 'YapiVenta no calcula distancias ni usa GPS '
                'automáticamente: define tú las zonas y sus costos.',
          ),
        ],
      ),
      _ => const _Contenido(
        titulo: 'Cómo cobras a tus clientes.',
        bloques: [
          (
            icono: Icons.currency_exchange_outlined,
            titulo: 'Métodos de pago',
            texto: 'Define los métodos que el negocio acepta, '
                'como Efectivo, Yape/Plin o transferencia.',
          ),
          (
            icono: Icons.info_outline,
            titulo: 'Sin verificación automática',
            texto: 'YapiVenta no verifica depósitos automáticamente: '
                'confirma tú cada pago.',
          ),
        ],
      ),
    };
  }
}

/// Encabezado de la tarjeta. El "Paso N de 4" se eliminó: el stepper del
/// centro ya comunica la posición, y repetirlo recargaba la vista.
class _Encabezado extends StatelessWidget {
  final bool compacto;

  const _Encabezado({required this.compacto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.info_outline, color: AppColors.blueLt, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Información',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.texto,
              fontSize: compacto ? 14 : 15,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hairline interna: separa secciones sin crear otra caja. Ocupa todo el ancho
/// de la tarjeta, así que la columna que la contiene va alineada al inicio.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 1,
      color: AppColors.bordeSutil,
    );
  }
}

/// Ítem de la lista de "Aquí registrarás:".
///
/// El check es decorativo y neutro: la lista describe qué se rellena en este
/// paso, no qué está ya rellenado, así que no debe sugerir un estado.
class _ItemMarcado extends StatelessWidget {
  final String texto;

  const _ItemMarcado({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, size: 13, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
