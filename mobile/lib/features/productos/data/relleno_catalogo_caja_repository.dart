import 'package:cloud_firestore/cloud_firestore.dart';

import '../application/services/relleno_catalogo_caja.dart';
import '../domain/repositories/repositorio_relleno_catalogo.dart';
import 'mappers/producto_firestore_mapper.dart';

/// Relleno único del catálogo de Caja bajo `negocios/{id}/productos`.
///
/// La marca `catalogoCajaListo` vive en el documento del negocio (que la app
/// ya tiene): saber si hace falta preparar no lee productos. Rellenar lee los
/// productos UNA vez, escribe solo lo que falta (en lotes de 400) y, al
/// terminar bien, pone la marca. Repetirlo después de un corte solo completa
/// lo pendiente.
///
/// Límite conocido: si el cajero vendiera un producto justo mientras se
/// rellena, el contador `vendidos` de ese producto podría volver a 0. La
/// pantalla no deja vender hasta que termina.
class RellenoCatalogoCajaRepository implements RepositorioRellenoCatalogo {
  RellenoCatalogoCajaRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String campoMarca = 'catalogoCajaListo';
  static const int _tamanoLote = 400;

  DocumentReference<Map<String, dynamic>> _negocio(String negocioId) {
    final id = negocioId.trim();
    if (id.isEmpty) {
      throw StateError('No se encontró un negocioId para preparar Caja.');
    }
    return _db.collection('negocios').doc(id);
  }

  @override
  Future<bool> catalogoListo(String negocioId) async {
    final doc = await _negocio(negocioId).get();
    return doc.data()?[campoMarca] == true;
  }

  @override
  Future<ResultadoRelleno> rellenar(String negocioId) async {
    final negocio = _negocio(negocioId);
    // Un documento de más solo para saber si pasa del tope.
    final lectura = await negocio
        .collection('productos')
        .limit(RellenoCatalogoCaja.maximoProductos + 1)
        .get();
    if (lectura.docs.length > RellenoCatalogoCaja.maximoProductos) {
      return ResultadoRelleno(demasiados: true, total: lectura.docs.length);
    }

    final pendientes =
        <DocumentReference<Map<String, dynamic>>, Map<String, Object>>{};
    var yaCompletos = 0;
    var omitidos = 0;
    for (final doc in lectura.docs) {
      final datos = doc.data();
      final producto = ProductoFirestoreMapper.desdeFirestore(doc.id, datos);
      if (producto == null) {
        omitidos++;
        continue;
      }
      final faltan = RellenoCatalogoCaja.camposFaltantes(datos, producto);
      if (faltan.isEmpty) {
        yaCompletos++;
      } else {
        pendientes[doc.reference] = faltan;
      }
    }

    final referencias = pendientes.keys.toList();
    for (var i = 0; i < referencias.length; i += _tamanoLote) {
      final lote = _db.batch();
      for (final ref in referencias.skip(i).take(_tamanoLote)) {
        lote.update(ref, pendientes[ref]!);
      }
      await lote.commit();
    }

    // La marca va al final: si algo falló antes, Caja volverá a ofrecerlo.
    await negocio.update({campoMarca: true});

    return ResultadoRelleno(
      actualizados: referencias.length,
      yaCompletos: yaCompletos,
      omitidos: omitidos,
      total: lectura.docs.length,
    );
  }
}
