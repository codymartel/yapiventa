import 'package:flutter/material.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_relleno_catalogo.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/services/textos_preparacion_catalogo.dart';
import '../providers/preparacion_catalogo_provider.dart';
import 'botones_caja.dart';

// ═════════════════════════════════════════════════════════════════════════
// ContenidoPreparacionCatalogo
// ═════════════════════════════════════════════════════════════════════════
// Lo que se ve dentro de la hoja (celular) o del diálogo (PC) al preparar el
// catálogo para Caja, según el estado (maqueta B10):
//
//   pideConfirmar → qué se hará y «Preparar ahora» / «Más tarde»
//   preparando    → progreso; no se puede cerrar ni cobrar
//   lista         → cuántos productos se revisaron y «Empezar a vender»
//   error         → «Reintentar» / «Más tarde» (lo hecho se conserva)
//   demasiados    → más de 500 productos: «Entendido»
//
// Solo dibuja: las acciones llegan por callbacks. Un botón principal por
// estado; textos como texto plano.
// ═════════════════════════════════════════════════════════════════════════
class ContenidoPreparacionCatalogo extends StatelessWidget {
  const ContenidoPreparacionCatalogo({
    super.key,
    required this.estado,
    this.resultado,
    required this.onPreparar,
    required this.onMasTarde,
    required this.onEmpezar,
  });

  final EstadoPreparacion estado;
  final ResultadoRelleno? resultado;

  /// «Preparar ahora» y «Reintentar».
  final VoidCallback onPreparar;

  /// «Más tarde» y «Entendido».
  final VoidCallback onMasTarde;
  final VoidCallback onEmpezar;

  @override
  Widget build(BuildContext context) {
    return switch (estado) {
      EstadoPreparacion.preparando => const _Preparando(),
      EstadoPreparacion.lista => _Lista(
        resultado: resultado,
        onEmpezar: onEmpezar,
      ),
      EstadoPreparacion.error => _Aviso(
        color: AppColors.error,
        titulo: 'No se pudo terminar',
        texto:
            'Revisa tu conexión e inténtalo de nuevo. Lo que ya se preparó se '
            'conserva.',
        principal: 'Reintentar',
        onPrincipal: onPreparar,
        secundario: 'Más tarde',
        onSecundario: onMasTarde,
      ),
      EstadoPreparacion.demasiados => _Aviso(
        color: AppColors.aviso,
        titulo: 'Tienes más de 500 productos',
        texto:
            'Caja admite hasta 500. Elimina los que ya no vendes y vuelve a '
            'intentar. No se cambió nada.',
        principal: 'Entendido',
        onPrincipal: onMasTarde,
      ),
      _ => _Confirmar(onPreparar: onPreparar, onMasTarde: onMasTarde),
    };
  }
}

class _Confirmar extends StatelessWidget {
  const _Confirmar({required this.onPreparar, required this.onMasTarde});

  final VoidCallback onPreparar;
  final VoidCallback onMasTarde;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.blueLt.withValues(alpha: 0.18),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: AppColors.azulTexto,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Prepara tu catálogo para Caja',
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Se hace una sola vez. Revisamos tus productos y les agregamos lo '
          'necesario para buscarlos rápido en Caja.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.bordeMedio),
          ),
          child: const Column(
            children: [
              _Punto(
                icono: Icons.check_circle_outline,
                color: AppColors.ok,
                texto: 'No cambia precios, fotos ni stock',
              ),
              _Punto(
                icono: Icons.check_circle_outline,
                color: AppColors.ok,
                texto: 'Tarda unos segundos',
              ),
              _Punto(
                icono: Icons.warning_amber_rounded,
                color: AppColors.aviso,
                texto: 'Necesitas conexión a internet',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BotonPrincipalCaja(texto: 'Preparar ahora', onTap: onPreparar),
        const SizedBox(height: 8),
        BotonSecundarioCaja(texto: 'Más tarde', onTap: onMasTarde),
      ],
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.icono, required this.color, required this.texto});

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preparando extends StatelessWidget {
  const _Preparando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 5),
          ),
          SizedBox(height: 16),
          Text(
            'Preparando tu catálogo…',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No cierres Caja ni cobres todavía. Esto termina en unos '
            'segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.resultado, required this.onEmpezar});

  final ResultadoRelleno? resultado;
  final VoidCallback onEmpezar;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.check_circle_outline, size: 48, color: AppColors.ok),
        const SizedBox(height: 8),
        const Text(
          'Catálogo listo',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (r != null) ...[
          const SizedBox(height: 8),
          Text(
            TextosPreparacionCatalogo.revisados(r.total),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            TextosPreparacionCatalogo.detalle(r),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.hint, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        BotonPrincipalCaja(texto: 'Empezar a vender', onTap: onEmpezar),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.color,
    required this.titulo,
    required this.texto,
    required this.principal,
    required this.onPrincipal,
    this.secundario,
    this.onSecundario,
  });

  final Color color;
  final String titulo;
  final String texto;
  final String principal;
  final VoidCallback onPrincipal;
  final String? secundario;
  final VoidCallback? onSecundario;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      texto,
                      style: TextStyle(color: color, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (secundario == null)
          BotonSecundarioCaja(texto: principal, onTap: onPrincipal)
        else ...[
          BotonPrincipalCaja(texto: principal, onTap: onPrincipal),
          const SizedBox(height: 8),
          BotonSecundarioCaja(texto: secundario!, onTap: onSecundario!),
        ],
      ],
    );
  }
}
