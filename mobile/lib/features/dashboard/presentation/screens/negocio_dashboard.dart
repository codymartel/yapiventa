import 'package:flutter/material.dart';

import '../../../auth/domain/politica_acceso.dart';
import '../../../negocio/data/negocio_repository.dart';
import '../../../negocio/domain/models/progreso_configuracion.dart';
import '../../../negocio/presentation/providers/configuracion_negocio_provider.dart';

/// Arma la sección de los datos del negocio dentro del tablero (datos,
/// catálogo, entrega y pagos): crea su provider una sola vez, la abre en el
/// navegador de Inicio y recuerda si se llegó desde el formulario de un
/// producto («Guardar y volver al producto»).
///
/// No dibuja nada ni llama a `setState`: el tablero decide qué sección queda
/// activa. Así `dashboard_web_screen.dart` no crece con cada sección.
class NegocioDashboard {
  NegocioDashboard({required this.negocioId, required this.navegador});

  final String? negocioId;

  /// El navegador de Inicio, donde vive la ruta de la sección.
  final GlobalKey<NavigatorState> navegador;

  ConfiguracionNegocioProvider? _provider;

  /// Se llegó desde el formulario de un producto: muestra «Guardar y volver
  /// al producto».
  bool vieneDeProducto = false;

  /// Cada +1 le dice a Productos que reabra el formulario que quedó a medias.
  final ValueNotifier<int> volverAlProducto = ValueNotifier<int>(0);

  /// Nulo hasta la primera vez que se abre (no se crea al entrar al tablero).
  ConfiguracionNegocioProvider? get provider => _provider;

  /// Si la etapa de configuración deja abrir la sección.
  static bool permitida(ProgresoConfiguracion progreso) =>
      PoliticaAcceso.permite(RutasAcceso.negocio, progreso);

  /// Crea el provider si falta y empuja la ruta en el navegador de Inicio.
  /// Antes, comprobar [permitida].
  void abrir(ProgresoConfiguracion progreso, NegocioRepository repository) {
    _provider ??= ConfiguracionNegocioProvider(
      rubro: progreso.catalogo.rubro,
      negocioId: negocioId,
      configuracionInicial: progreso.catalogo.configuracionInicial,
      repository: repository,
    );
    navegador.currentState!.pushNamed(RutasAcceso.negocio);
  }

  /// Desde el formulario de producto: Catálogo → Unidades de venta, donde se
  /// crean las presentaciones propias. Llamar después de [abrir].
  void irAUnidadesDeVenta() {
    _provider
      ?..irAPaso(1)
      ..cambiarCatalogoPestana(1);
  }

  /// Cierra las rutas internas y deja Inicio a la vista.
  void cerrarRutas() {
    navegador.currentState?.popUntil((ruta) => ruta.isFirst);
  }

  /// El rubro cambió: el provider viejo ya no sirve y se arma de nuevo al
  /// volver a abrir.
  void olvidarProvider() {
    _provider?.dispose();
    _provider = null;
  }

  void dispose() {
    _provider?.dispose();
    volverAlProducto.dispose();
  }
}
