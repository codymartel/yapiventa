import '../../domain/models/pagina_productos.dart';
import '../../domain/repositories/repositorio_productos.dart';

class ObtenerPaginaProductos {
  final RepositorioProductos _repositorioProductos;

  const ObtenerPaginaProductos(this._repositorioProductos);

  Future<PaginaProductos> call({
    required String uid,
    CursorProductos? despuesDe,
    int limite = 10,
  }) {
    return _repositorioProductos.obtenerPaginaProductos(
      uid,
      despuesDe: despuesDe,
      limite: limite,
    );
  }
}
