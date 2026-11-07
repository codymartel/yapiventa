import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pedidos/application/use_cases/anular_venta_mostrador.dart';
import 'package:mobile/features/pedidos/domain/repositories/repositorio_ventas_mostrador.dart';

class _Repo implements RepositorioVentasMostrador {
  String? negocio;
  String? pedido;

  @override
  Future<ResultadoVentaMostrador> registrar(
    String negocioId,
    SolicitudVentaMostrador solicitud,
  ) async => const ResultadoVentaMostrador();

  @override
  Future<ResultadoAnulacion> anular(String negocioId, String pedidoId) async {
    negocio = negocioId;
    pedido = pedidoId;
    return const ResultadoAnulacion(sinDevolver: 1);
  }
}

void main() {
  test('manda a anular la venta del negocio y devuelve el resultado', () async {
    final repo = _Repo();
    final r = await AnularVentaMostrador(repo)(negocioId: 'n1', pedidoId: 'v1');

    expect(repo.negocio, 'n1');
    expect(repo.pedido, 'v1');
    expect(r.sinDevolver, 1);
  });

  test('una venta sin id es un error de programación', () {
    expect(
      () => AnularVentaMostrador(_Repo())(negocioId: 'n1', pedidoId: '  '),
      throwsArgumentError,
    );
  });
}
