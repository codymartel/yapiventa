import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../productos/domain/models/familia_unidad.dart';
import '../../domain/models/catalogo_venta/catalogo_venta_persistido.dart';
import '../../domain/models/catalogo_venta/configuracion_medida.dart';
import '../../domain/models/catalogo_venta/formateador_presentacion.dart';
import '../../domain/models/catalogo_venta/unidad_registrada.dart';
import '../providers/configuracion_negocio_provider.dart';

// ═════════════════════════════════════════════════════════════════════════
// SeccionMedidas — pestaña "Medidas" del paso Catálogo
// ═════════════════════════════════════════════════════════════════════════
//
// La interfaz "Venta por medida": tarjetas de las medidas del rubro (peso,
// volumen, longitud, área) y su editor. Muestra por medida: nombre, familia
// protegida, unidad base protegida, unidad habitual, mínimo, incremento,
// cantidades rápidas, venta por cantidad, venta por soles y activa/inactiva.
//
// REGLAS heredadas del dominio (ConfiguracionMedida):
//   - Los valores se escriben SIEMPRE en la unidad base (g, ml, mm, cm²).
//   - La unidad habitual se elige de un dropdown filtrado a la familia
//     (nunca texto libre): Peso g/kg, Volumen ml/L, Longitud mm/cm/m,
//     Área cm²/m².
//   - Las cantidades rápidas son enteros con unidad + botones 1/4, 1/2,
//     3/4 y 1 de la unidad de referencia.
//   - No se usan double: las etiquetas salen por FormateadorPresentacion
//     (250 g → 1/4 kg, 1500 ml → 1 1/2 L, 600 ml → 600 ml).
//   - El editor valida antes de guardar con los mismos criterios (y
//     mensajes) que el provider: mínimo>0, incremento>0, rápidas fieles a
//     mínimo+incremento, sin duplicados, unidad de la familia, y al menos
//     venta por cantidad o por monto.
//
// NO calcula precios, NO toca Productos ni la web.
// ═════════════════════════════════════════════════════════════════════════

class SeccionMedidas extends StatelessWidget {
  const SeccionMedidas({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConfiguracionNegocioProvider>();
    final medidas = p.medidas;
    final activas = medidas.where((medida) => medida.activa).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CabeceraMedidas(cantidadActivas: activas),
        const SizedBox(height: 16),
        if (medidas.isEmpty)
          const Text(
            'Aún no hay medidas configuradas para este rubro.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          )
        else
          for (final medida in medidas) ...[
            TarjetaMedida(
              medida: medida,
              onEditar:
                  medida.requiereRevision ||
                      medida.familia == null ||
                      medida.unidadVisual == null
                  ? null
                  : () => _abrirEditorMedida(context, medida.familia!),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _CabeceraMedidas extends StatelessWidget {
  final int cantidadActivas;

  const _CabeceraMedidas({required this.cantidadActivas});

  @override
  Widget build(BuildContext context) {
    final titulo = const Text(
      'Venta por medida',
      style: TextStyle(
        color: AppColors.texto,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
    final descripcion = const Text(
      'Define cómo se vende por peso, volumen, longitud o área: '
      'mínimo, incremento y cantidades rápidas desde la unidad base.',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: AppColors.muted, fontSize: 13),
    );
    final contador = Text(
      '$cantidadActivas activas',
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titulo, const SizedBox(height: 4), descripcion],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [contador],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titulo,
            const SizedBox(height: 4),
            descripcion,
            const SizedBox(height: 12),
            contador,
          ],
        );
      },
    );
  }
}

class TarjetaMedida extends StatelessWidget {
  final MedidaVentaPersistida medida;
  final VoidCallback? onEditar;

  const TarjetaMedida({super.key, required this.medida, this.onEditar});

  @override
  Widget build(BuildContext context) {
    final familia = medida.familia;
    final base = medida.unidadBase;
    final visual = medida.unidadVisual;
    final familiaLegible = familia == null ? '—' : _nombreFamilia(familia);
    final baseLegible = base?.nombre ?? '—';
    final visualLegible = visual?.nombre ?? '—';

    final rapidaEtiquetas = (familia != null && visual != null)
        ? medida.cantidadesRapidasBase
              .map(
                (valor) => FormateadorPresentacion.formatear(
                  FormateadorPresentacion.cantidadEnFamilia(familia, valor),
                  visual,
                ),
              )
              .join(', ')
        : null;

    final minimo = (base != null && medida.minimoBase > 0)
        ? '${medida.minimoBase} ${base.nombre}'
        : '—';
    final incremento = (base != null && medida.incrementoBase > 0)
        ? '${medida.incrementoBase} ${base.nombre}'
        : '—';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Material(
        key: Key('medida-card-${familia?.name ?? medida.id}'),
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medida.nombre,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _EstadoMedida(activa: medida.activa),
                  if (medida.requiereRevision)
                    const _EtiquetaChipMedida(
                      texto: 'Requiere revisión',
                      color: AppColors.error,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _LineaTarjeta('Familia: $familiaLegible'),
              _LineaTarjeta(
                'Unidad base: $baseLegible  ·  Unidad habitual: '
                '$visualLegible',
              ),
              _LineaTarjeta('Mínimo: $minimo  ·  Incremento: $incremento'),
              _LineaTarjeta('Cantidades rápidas: ${rapidaEtiquetas ?? '—'}'),
              _LineaTarjeta(
                'Por cantidad: ${medida.permiteCantidad ? 'Sí' : 'No'}  ·  '
                'Por soles: ${medida.permiteMonto ? 'Sí' : 'No'}',
              ),
              if (onEditar != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: Key('editar-medida-${familia?.name ?? medida.id}'),
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LineaTarjeta extends StatelessWidget {
  final String texto;

  const _LineaTarjeta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        texto,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }
}

class _EstadoMedida extends StatelessWidget {
  final bool activa;

  const _EstadoMedida({required this.activa});

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.blueLt : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(
          activa ? 'Activa' : 'Inactiva',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EtiquetaChipMedida extends StatelessWidget {
  final String texto;
  final Color color;

  const _EtiquetaChipMedida({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Future<void> _abrirEditorMedida(BuildContext context, FamiliaUnidad familia) {
  context.read<ConfiguracionNegocioProvider>().limpiarErrorCatalogo();
  return showDialog<void>(
    context: context,
    builder: (_) => EditorMedida(familia: familia),
  );
}

String _nombreFamilia(FamiliaUnidad familia) => switch (familia) {
  FamiliaUnidad.conteo => 'Conteo',
  FamiliaUnidad.peso => 'Peso',
  FamiliaUnidad.volumen => 'Volumen',
  FamiliaUnidad.longitud => 'Longitud',
  FamiliaUnidad.area => 'Área',
};

// ═════════════════════════════════════════════════════════════════════════
// Editor de medida
// ═════════════════════════════════════════════════════════════════════════

class EditorMedida extends StatefulWidget {
  final FamiliaUnidad familia;

  const EditorMedida({super.key, required this.familia});

  @override
  State<EditorMedida> createState() => _EditorMedidaState();
}

class _EditorMedidaState extends State<EditorMedida> {
  late final bool _bloqueada;
  late final String _nombre;
  late final UnidadRegistrada _unidadBase;
  late final bool _obligatoria;

  late UnidadRegistrada _unidadVisual;
  late List<int> _rapidas;
  late bool _permiteCantidad;
  late bool _permiteMonto;
  late bool _activa;

  late final TextEditingController _nombreController;
  late final TextEditingController _familiaController;
  late final TextEditingController _baseController;
  late final TextEditingController _minimoController;
  late final TextEditingController _incrementoController;
  final TextEditingController _rapidaValorController = TextEditingController();
  late UnidadRegistrada _rapidaUnidad;
  String? _error;

  int get _minimo => int.tryParse(_minimoController.text.trim()) ?? 0;
  int get _incremento => int.tryParse(_incrementoController.text.trim()) ?? 0;

  List<UnidadRegistrada> get _unidadesDeFamilia =>
      RegistroUnidades.unidadesDe(widget.familia);

  @override
  void initState() {
    super.initState();
    final p = context.read<ConfiguracionNegocioProvider>();
    final medida = p.medidaDe(widget.familia);
    final resuelta =
        medida != null &&
        medida.familia != null &&
        medida.unidadBase != null &&
        medida.unidadVisual != null;
    _bloqueada = !resuelta;
    _nombre = medida?.nombre ?? '';
    _unidadBase = medida?.unidadBase ?? RegistroUnidades.baseDe(widget.familia);
    _obligatoria = medida?.obligatoria ?? false;
    _unidadVisual = medida?.unidadVisual ?? _unidadBase;
    _rapidas = List.of(medida?.cantidadesRapidasBase ?? const []);
    _permiteCantidad = medida?.permiteCantidad ?? true;
    _permiteMonto = medida?.permiteMonto ?? false;
    _activa = medida?.activa ?? false;
    _nombreController = TextEditingController(text: _nombre);
    _familiaController = TextEditingController(
      text: _nombreFamilia(widget.familia),
    );
    _baseController = TextEditingController(text: _unidadBase.nombre);
    _minimoController = TextEditingController(
      text: medida != null && resuelta ? '${medida.minimoBase}' : '',
    );
    _incrementoController = TextEditingController(
      text: medida != null && resuelta ? '${medida.incrementoBase}' : '',
    );
    _rapidaUnidad = _unidadVisual;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _familiaController.dispose();
    _baseController.dispose();
    _minimoController.dispose();
    _incrementoController.dispose();
    _rapidaValorController.dispose();
    super.dispose();
  }

  String? _validarParaGuardar() => ConfiguracionMedida.validar(
    familia: widget.familia,
    unidadVisual: _unidadVisual,
    minimoBase: _minimo,
    incrementoBase: _incremento,
    cantidadesRapidasBase: _rapidas,
    permiteCantidad: _permiteCantidad,
    monto: _permiteMonto ? EstadoMonto.activo : EstadoMonto.inactivo,
  );

  void _proponerRapida(int base) {
    final propuesta = [..._rapidas, base];
    final error = ConfiguracionMedida.validar(
      familia: widget.familia,
      unidadVisual: _unidadVisual,
      minimoBase: _minimo,
      incrementoBase: _incremento,
      cantidadesRapidasBase: propuesta,
      permiteCantidad: _permiteCantidad,
      monto: _permiteMonto ? EstadoMonto.activo : EstadoMonto.inactivo,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _rapidas = propuesta;
      _error = null;
      _rapidaValorController.clear();
    });
  }

  void _agregarRapidaCustom() {
    final texto = _rapidaValorController.text.trim();
    final valor = int.tryParse(texto);
    if (valor == null || valor <= 0) {
      setState(
        () => _error = 'La cantidad rápida debe ser un entero positivo.',
      );
      return;
    }
    _proponerRapida(valor * _rapidaUnidad.factorBase);
  }

  void _agregarFraccionDeReferencia(int partes) {
    final factor = _unidadVisual.factorBase;
    if (factor % 4 != 0) return;
    _proponerRapida(factor * partes ~/ 4);
  }

  void _eliminarRapida(int base) {
    setState(() {
      _rapidas = [..._rapidas]..remove(base);
      _error = null;
    });
  }

  bool _listasIguales(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _guardar() {
    final p = context.read<ConfiguracionNegocioProvider>();
    final error = _validarParaGuardar();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    void cancelarPorError() {
      final mensaje = p.errorCatalogo;
      if (mensaje != null) setState(() => _error = mensaje);
    }

    var actual = p.medidaDe(widget.familia)!;
    if (_unidadVisual != actual.unidadVisual) {
      p.editarUnidadVisual(widget.familia, _unidadVisual);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    actual = p.medidaDe(widget.familia)!;
    if (_minimo != actual.minimoBase) {
      p.editarMinimoBase(widget.familia, _minimo);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    actual = p.medidaDe(widget.familia)!;
    if (_incremento != actual.incrementoBase) {
      p.editarIncrementoBase(widget.familia, _incremento);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    actual = p.medidaDe(widget.familia)!;
    if (!_listasIguales(_rapidas, actual.cantidadesRapidasBase)) {
      p.editarCantidadesRapidasBase(widget.familia, _rapidas);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    actual = p.medidaDe(widget.familia)!;
    if (_permiteCantidad != actual.permiteCantidad) {
      p.establecerPermiteCantidad(widget.familia, permite: _permiteCantidad);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    actual = p.medidaDe(widget.familia)!;
    if (_permiteMonto != actual.permiteMonto) {
      p.establecerPermiteMonto(widget.familia, permite: _permiteMonto);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    actual = p.medidaDe(widget.familia)!;
    if (_activa != actual.activa) {
      p.establecerMedidaActiva(widget.familia, activa: _activa);
      if (p.errorCatalogo != null) {
        cancelarPorError();
        return;
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('editor-medida'),
      backgroundColor: AppColors.superficie,
      title: Text(
        _bloqueada ? _nombre : 'Editar $_nombre',
        style: const TextStyle(color: AppColors.texto),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('campo-nombre-medida'),
                enabled: false,
                controller: _nombreController,
                style: const TextStyle(color: AppColors.texto),
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  suffixText: 'Medida del catálogo',
                  helperText: 'Los nombres del catálogo son fijos.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('campo-familia-medida'),
                enabled: false,
                controller: _familiaController,
                style: const TextStyle(color: AppColors.texto),
                decoration: const InputDecoration(labelText: 'Familia'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('campo-unidadbase-medida'),
                enabled: false,
                controller: _baseController,
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  labelText: 'Unidad base',
                  helperText:
                      'La unidad base está protegida: ${_unidadBase.nombre}.',
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                key: const Key('campo-unidad-medida'),
                decoration: const InputDecoration(labelText: 'Unidad habitual'),
                child: DropdownButton<UnidadRegistrada>(
                  value: _unidadVisual,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  selectedItemBuilder: (context) => [
                    for (final unidad in _unidadesDeFamilia)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          unidad.nombre,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                  items: [
                    for (final unidad in _unidadesDeFamilia)
                      DropdownMenuItem(
                        value: unidad,
                        child: Text(
                          unidad.nombre,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (unidad) {
                    if (unidad == null) return;
                    setState(() {
                      _unidadVisual = unidad;
                      _error = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              _campoNumero(
                clave: 'campo-minimo-medida',
                controller: _minimoController,
                etiqueta: 'Mínimo (en ${_unidadBase.nombre})',
                sufijo: _unidadBase.nombre,
                onCambio: () {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 12),
              _campoNumero(
                clave: 'campo-incremento-medida',
                controller: _incrementoController,
                etiqueta: 'Incremento (en ${_unidadBase.nombre})',
                sufijo: _unidadBase.nombre,
                onCambio: () {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Cantidades rápidas',
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              for (final base in _rapidas)
                _FilaRapidaExistente(
                  base: base,
                  etiqueta: _etiquetaDeRapida(
                    widget.familia,
                    _unidadVisual,
                    base,
                  ),
                  onEliminar: () => _eliminarRapida(base),
                ),
              const SizedBox(height: 8),
              EditorCantidadRapida(
                unidades: _unidadesDeFamilia,
                referencia: _unidadVisual,
                valorController: _rapidaValorController,
                unidadSeleccionada: _rapidaUnidad,
                onUnidadCambio: (unidad) {
                  if (unidad == null) return;
                  setState(() {
                    _rapidaUnidad = unidad;
                    _error = null;
                  });
                },
                onValorCambio: () {
                  if (_error != null) setState(() => _error = null);
                },
                onAgregar: _agregarRapidaCustom,
                onFraccion: _agregarFraccionDeReferencia,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('switch-permitir-cantidad-medida'),
                value: _permiteCantidad,
                onChanged: (valor) => setState(() {
                  _permiteCantidad = valor;
                  _error = null;
                }),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Permitir pedido por cantidad',
                  style: TextStyle(color: AppColors.texto, fontSize: 13),
                ),
              ),
              SwitchListTile(
                key: const Key('switch-permitir-monto-medida'),
                value: _permiteMonto,
                onChanged: (valor) => setState(() {
                  _permiteMonto = valor;
                  _error = null;
                }),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Permitir pedido por soles',
                  style: TextStyle(color: AppColors.texto, fontSize: 13),
                ),
              ),
              SwitchListTile(
                key: const Key('switch-activa-medida'),
                value: _activa,
                onChanged: _obligatoria
                    ? null
                    : (valor) => setState(() {
                        _activa = valor;
                        _error = null;
                      }),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _obligatoria
                      ? 'Obligatoria (siempre activa)'
                      : _activa
                      ? 'Activa'
                      : 'Inactiva',
                  style: const TextStyle(color: AppColors.texto, fontSize: 13),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('error-editor-medida'),
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              PrevisualizacionMedida(
                nombre: _nombre,
                familia: widget.familia,
                unidadBase: _unidadBase,
                unidadVisual: _unidadVisual,
                minimoBase: _minimo,
                incrementoBase: _incremento,
                rapidasBase: _rapidas,
                permiteCantidad: _permiteCantidad,
                permiteMonto: _permiteMonto,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        ElevatedButton(
          key: const Key('guardar-editor-medida'),
          onPressed: _bloqueada ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

Widget _campoNumero({
  required String clave,
  required TextEditingController controller,
  required String etiqueta,
  required String sufijo,
  required VoidCallback onCambio,
}) {
  return TextField(
    key: Key(clave),
    controller: controller,
    keyboardType: TextInputType.number,
    style: const TextStyle(color: AppColors.texto),
    decoration: InputDecoration(labelText: etiqueta, suffixText: sufijo),
    onChanged: (_) => onCambio(),
  );
}

String _etiquetaDeRapida(
  FamiliaUnidad familia,
  UnidadRegistrada unidad,
  int base,
) => FormateadorPresentacion.formatear(
  FormateadorPresentacion.cantidadEnFamilia(familia, base),
  unidad,
);

class _FilaRapidaExistente extends StatelessWidget {
  final int base;
  final String etiqueta;
  final VoidCallback onEliminar;

  const _FilaRapidaExistente({
    required this.base,
    required this.etiqueta,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              key: Key('rapida-existente-$base'),
              style: const TextStyle(color: AppColors.texto, fontSize: 13),
            ),
          ),
          IconButton(
            key: Key('eliminar-rapida-$base'),
            tooltip: 'Quitar $etiqueta',
            onPressed: onEliminar,
            icon: Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Editor de cantidad rápida (entero + unidad + fracciones de referencia)
// ═════════════════════════════════════════════════════════════════════════

class EditorCantidadRapida extends StatelessWidget {
  final List<UnidadRegistrada> unidades;
  final UnidadRegistrada referencia;
  final TextEditingController valorController;
  final UnidadRegistrada unidadSeleccionada;
  final ValueChanged<UnidadRegistrada?> onUnidadCambio;
  final VoidCallback onValorCambio;
  final VoidCallback onAgregar;
  final ValueChanged<int> onFraccion;

  const EditorCantidadRapida({
    super.key,
    required this.unidades,
    required this.referencia,
    required this.valorController,
    required this.unidadSeleccionada,
    required this.onUnidadCambio,
    required this.onValorCambio,
    required this.onAgregar,
    required this.onFraccion,
  });

  @override
  Widget build(BuildContext context) {
    final campoValor = TextField(
      key: const Key('campo-valor-rapida'),
      controller: valorController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.texto),
      decoration: const InputDecoration(
        labelText: 'Cantidad',
        hintText: 'Ej: 250',
      ),
      onChanged: (_) => onValorCambio(),
    );
    final campoUnidad = InputDecorator(
      key: const Key('campo-unidad-rapida'),
      decoration: const InputDecoration(labelText: 'Unidad'),
      child: DropdownButton<UnidadRegistrada>(
        value: unidadSeleccionada,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        selectedItemBuilder: (context) => [
          for (final unidad in unidades)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                unidad.nombre,
                style: const TextStyle(color: AppColors.texto, fontSize: 16),
              ),
            ),
        ],
        items: [
          for (final unidad in unidades)
            DropdownMenuItem(
              value: unidad,
              child: Text(
                unidad.nombre,
                style: const TextStyle(color: AppColors.texto, fontSize: 16),
              ),
            ),
        ],
        onChanged: onUnidadCambio,
      ),
    );
    final botonAgregar = IconButton.filledTonal(
      key: const Key('boton-agregar-rapida'),
      tooltip: 'Agregar cantidad rápida',
      onPressed: onAgregar,
      icon: const Icon(Icons.add),
    );

    final fracciones = referencia.factorBase % 4 == 0
        ? [
            _BotonFraccion(
              clave: 'boton-fraccion-rapida-1',
              etiqueta: '1/4',
              onTap: () => onFraccion(1),
            ),
            _BotonFraccion(
              clave: 'boton-fraccion-rapida-2',
              etiqueta: '1/2',
              onTap: () => onFraccion(2),
            ),
            _BotonFraccion(
              clave: 'boton-fraccion-rapida-3',
              etiqueta: '3/4',
              onTap: () => onFraccion(3),
            ),
            _BotonFraccion(
              clave: 'boton-fraccion-rapida-4',
              etiqueta: '1',
              onTap: () => onFraccion(4),
            ),
          ]
        : const <Widget>[];

    final filaEntrada = MediaQuery.sizeOf(context).width >= 520
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: campoValor),
              const SizedBox(width: 10),
              Expanded(child: campoUnidad),
              const SizedBox(width: 8),
              botonAgregar,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              campoValor,
              const SizedBox(height: 10),
              campoUnidad,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: botonAgregar),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filaEntrada,
        if (fracciones.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Rápida de referencia (${referencia.nombre}):',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: fracciones),
        ],
      ],
    );
  }
}

class _BotonFraccion extends StatelessWidget {
  final String clave;
  final String etiqueta;
  final VoidCallback onTap;

  const _BotonFraccion({
    required this.clave,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: Key(clave),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: AppColors.blueLt,
      ),
      child: Text(
        etiqueta,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Previsualización de medida
// ═════════════════════════════════════════════════════════════════════════

class PrevisualizacionMedida extends StatelessWidget {
  final String nombre;
  final FamiliaUnidad familia;
  final UnidadRegistrada unidadBase;
  final UnidadRegistrada unidadVisual;
  final int minimoBase;
  final int incrementoBase;
  final List<int> rapidasBase;
  final bool permiteCantidad;
  final bool permiteMonto;

  const PrevisualizacionMedida({
    super.key,
    required this.nombre,
    required this.familia,
    required this.unidadBase,
    required this.unidadVisual,
    required this.minimoBase,
    required this.incrementoBase,
    required this.rapidasBase,
    required this.permiteCantidad,
    required this.permiteMonto,
  });

  String _etiqueta(int base) => FormateadorPresentacion.formatear(
    FormateadorPresentacion.cantidadEnFamilia(familia, base),
    unidadVisual,
  );

  static const _margen = TextStyle(color: AppColors.muted, fontSize: 13);
  static const _negrita = TextStyle(
    color: AppColors.texto,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final minimoValido = minimoBase > 0;
    final incrementoValido = incrementoBase > 0;
    final secuencia = (minimoValido && incrementoValido)
        ? List.generate(
            4,
            (i) => '${minimoBase + i * incrementoBase} ${unidadBase.nombre}',
          ).join(', ')
        : null;

    return Container(
      key: const Key('previsualizacion-medida'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cómo lo verá el cliente',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(nombre, style: _negrita),
          const SizedBox(height: 4),
          Text(
            minimoValido
                ? 'Mínimo: $minimoBase ${unidadBase.nombre}'
                : 'Mínimo: —',
            style: _margen,
          ),
          Text(
            incrementoValido
                ? 'Incremento: $incrementoBase ${unidadBase.nombre}'
                : 'Incremento: —',
            style: _margen,
          ),
          Text(
            secuencia != null ? 'Secuencia: $secuencia...' : 'Secuencia: —',
            style: _margen,
          ),
          if (rapidasBase.isNotEmpty)
            Text(
              'Opciones rápidas: ${rapidasBase.map(_etiqueta).join(', ')}',
              style: _margen,
            ),
          Text(
            'Por cantidad: ${permiteCantidad ? 'Sí' : 'No'}',
            style: _margen,
          ),
          Text('Por soles: ${permiteMonto ? 'Sí' : 'No'}', style: _margen),
        ],
      ),
    );
  }
}
