import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/services/textos_entrega_caja.dart';
import '../providers/venta_caja_provider.dart';
import 'piezas_caja.dart';

/// Los datos del cliente según la entrega: en tienda o recojo solo un nombre
/// opcional; con delivery, nombre, teléfono y dirección (obligatorios). La
/// nota es siempre opcional. Lo escrito se guarda en el provider de la venta
/// y se limpia solo cuando la venta se cobra o se vacía.
class DatosClienteCaja extends StatefulWidget {
  const DatosClienteCaja({
    super.key,
    required this.provider,
    required this.rubro,
  });

  final VentaCajaProvider provider;
  final String rubro;

  @override
  State<DatosClienteCaja> createState() => _DatosClienteCajaState();
}

class _DatosClienteCajaState extends State<DatosClienteCaja> {
  late final _cliente = TextEditingController(text: _p.cliente);
  late final _telefono = TextEditingController(text: _p.telefono);
  late final _direccion = TextEditingController(text: _p.direccion);
  late final _notas = TextEditingController(text: _p.notas);

  VentaCajaProvider get _p => widget.provider;

  @override
  void initState() {
    super.initState();
    _p.addListener(_sincronizar);
  }

  @override
  void dispose() {
    _p.removeListener(_sincronizar);
    _cliente.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _notas.dispose();
    super.dispose();
  }

  /// Si el provider cambió por fuera (se cobró o se vació), los campos lo
  /// reflejan. Mientras se escribe, el texto ya coincide y no se toca.
  void _sincronizar() {
    void poner(TextEditingController c, String valor) {
      if (c.text != valor) c.text = valor;
    }

    poner(_cliente, _p.cliente);
    poner(_telefono, _p.telefono);
    poner(_direccion, _p.direccion);
    poner(_notas, _p.notas);
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _p.esDelivery;
    final nombre = CampoCaja(
      etiqueta: TextosEntregaCaja.ayudaCliente(_p.entrega, rubro: widget.rubro),
      controller: _cliente,
      onChanged: _p.escribirCliente,
      ejemplo: 'Por ejemplo: Rosa',
      teclado: TextInputType.name,
      maximo: 80,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!delivery)
          nombre
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: nombre),
              const SizedBox(width: 8),
              Expanded(
                child: CampoCaja(
                  etiqueta: 'Teléfono',
                  controller: _telefono,
                  onChanged: _p.escribirTelefono,
                  ejemplo: '987 654 321',
                  teclado: TextInputType.phone,
                  maximo: 20,
                  formatos: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CampoCaja(
            etiqueta: 'Dirección',
            controller: _direccion,
            onChanged: _p.escribirDireccion,
            ejemplo: 'Calle, número y referencia',
            teclado: TextInputType.streetAddress,
            maximo: 200,
            lineas: 2,
          ),
        ],
        const SizedBox(height: 12),
        CampoCaja(
          etiqueta: 'Nota (opcional)',
          controller: _notas,
          onChanged: _p.escribirNotas,
          ejemplo: 'Por ejemplo: sin bolsa',
          maximo: 500,
          accion: TextInputAction.done,
          lineas: 2,
        ),
      ],
    );
  }
}
