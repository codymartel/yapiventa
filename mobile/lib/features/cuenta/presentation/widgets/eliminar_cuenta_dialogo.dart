import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/eliminar_cuenta_provider.dart';

/// Palabra que el usuario debe escribir para confirmar.
const palabraConfirmacion = 'ELIMINAR';

/// Abre el diálogo y le entrega su estado. Si se borra, el diálogo se cierra y
/// la app vuelve sola al inicio de sesión (ya no hay usuario).
Future<void> mostrarEliminarCuenta(
  BuildContext context, {
  required EliminarCuentaProvider Function() crearProvider,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ChangeNotifierProvider<EliminarCuentaProvider>(
      create: (_) => crearProvider(),
      child: const EliminarCuentaDialogo(),
    ),
  );
}

class EliminarCuentaDialogo extends StatefulWidget {
  const EliminarCuentaDialogo({super.key});

  @override
  State<EliminarCuentaDialogo> createState() => _EliminarCuentaDialogoState();
}

class _EliminarCuentaDialogoState extends State<EliminarCuentaDialogo> {
  final _palabra = TextEditingController();
  final _clave = TextEditingController();

  @override
  void dispose() {
    _palabra.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _eliminar() async {
    final navegador = Navigator.of(context);
    final eliminada = await context.read<EliminarCuentaProvider>().eliminar(
      clave: _clave.text,
    );
    if (eliminada && navegador.mounted) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EliminarCuentaProvider>();
    final confirmada =
        _palabra.text.trim().toUpperCase() == palabraConfirmacion;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Eliminar mi cuenta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se borrarán para siempre tu negocio, tus productos, tus pedidos '
              'con los datos de tus clientes, tu tienda web y tu acceso. '
              'Esto no se puede deshacer.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _palabra,
              enabled: !estado.trabajando,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Escribe $palabraConfirmacion para confirmar',
              ),
            ),
            if (estado.usaClave) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _clave,
                enabled: !estado.trabajando,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Tu contraseña'),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                'Te pediremos elegir tu cuenta de Google otra vez para confirmar.',
              ),
            ],
            if (estado.error != null) ...[
              const SizedBox(height: 10),
              Text(
                estado.error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            if (estado.trabajando) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text('Borrando tus datos… no cierres la app.'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: estado.trabajando
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: confirmada && !estado.trabajando ? _eliminar : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Eliminar para siempre'),
        ),
      ],
    );
  }
}
