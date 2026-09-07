import 'package:flutter/material.dart';

class DialogoEliminarProducto extends StatelessWidget {
  const DialogoEliminarProducto({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eliminar producto'),
      content: const Text('Esta accion no se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}
