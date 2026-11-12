import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/cuenta/application/eliminar_cuenta.dart';
import 'package:mobile/features/cuenta/data/eliminar_cuenta_repository.dart';

/// Anota en qué orden se borra, sin tocar Firestore.
class _RepositorioRegistro extends EliminarCuentaRepository {
  final List<String> pasos;
  final String? slug;
  final bool negocioExiste;
  final bool falla;

  _RepositorioRegistro(
    this.pasos, {
    this.slug = 'mi-tienda',
    this.negocioExiste = true,
    this.falla = false,
  }) : super(firestore: FakeFirebaseFirestore());

  @override
  Future<String?> marcarNegocioEnBorrado(String negocioId) async {
    pasos.add('marcar');
    return negocioExiste ? slug : null;
  }

  @override
  Future<void> borrarSubcoleccionDelNegocio(
    String negocioId,
    String nombre,
  ) async {
    pasos.add(nombre);
    if (falla) {
      throw FirebaseException(plugin: 'firestore', code: 'unavailable');
    }
  }

  @override
  Future<void> borrarPaginaPublica(String slug) async => pasos.add('publica');

  @override
  Future<void> borrarNegocio(String negocioId) async => pasos.add('negocio');

  @override
  Future<void> borrarPerfil(String uid) async => pasos.add('perfil');
}

void main() {
  group('orden del borrado', () {
    test(
      'marca, borra lo del negocio, el negocio, el perfil y al final el acceso',
      () async {
        final pasos = <String>[];
        final caso = EliminarCuenta(
          datos: _RepositorioRegistro(pasos),
          borrarUsuarioDeAcceso: () async => pasos.add('acceso'),
        );

        await caso.ejecutar(uid: 'u1', negocioId: 'n1');

        expect(pasos, [
          'marcar',
          'pedidos',
          'resumenes',
          'gastos',
          'productos',
          'publica',
          'negocio',
          'perfil',
          'acceso',
        ]);
      },
    );

    test('sin página pública (sin slug) no intenta borrarla', () async {
      final pasos = <String>[];
      await EliminarCuenta(
        datos: _RepositorioRegistro(pasos, slug: ''),
        borrarUsuarioDeAcceso: () async {},
      ).ejecutar(uid: 'u1', negocioId: 'n1');

      expect(pasos, isNot(contains('publica')));
      expect(pasos, contains('negocio'));
    });

    test(
      'si el negocio ya no existe (intento anterior) sigue con perfil y acceso',
      () async {
        final pasos = <String>[];
        await EliminarCuenta(
          datos: _RepositorioRegistro(pasos, negocioExiste: false),
          borrarUsuarioDeAcceso: () async => pasos.add('acceso'),
        ).ejecutar(uid: 'u1', negocioId: 'n1');

        expect(pasos, ['marcar', 'perfil', 'acceso']);
      },
    );

    test('sin negocio (aún no lo creó) solo borra perfil y acceso', () async {
      final pasos = <String>[];
      await EliminarCuenta(
        datos: _RepositorioRegistro(pasos),
        borrarUsuarioDeAcceso: () async => pasos.add('acceso'),
      ).ejecutar(uid: 'u1', negocioId: null);

      expect(pasos, ['perfil', 'acceso']);
    });

    test(
      'si falla Firestore NO borra el acceso: el usuario puede reintentar',
      () async {
        final pasos = <String>[];
        final caso = EliminarCuenta(
          datos: _RepositorioRegistro(pasos, falla: true),
          borrarUsuarioDeAcceso: () async => pasos.add('acceso'),
        );

        await expectLater(
          caso.ejecutar(uid: 'u1', negocioId: 'n1'),
          throwsA(isA<FirebaseException>()),
        );
        expect(pasos, isNot(contains('acceso')));
        expect(pasos, isNot(contains('negocio')));
      },
    );
  });

  group('con datos reales (Firestore simulado)', () {
    late FakeFirebaseFirestore firestore;
    late EliminarCuenta caso;
    var accesoBorrado = false;

    setUp(() async {
      accesoBorrado = false;
      firestore = FakeFirebaseFirestore();
      caso = EliminarCuenta(
        datos: EliminarCuentaRepository(firestore: firestore),
        borrarUsuarioDeAcceso: () async => accesoBorrado = true,
      );
      await firestore.doc('users/u1').set({'email': 'a@b.c'});
      await firestore.doc('users/u1/plan/actual').set({'tipo': 'free'});
      await firestore.doc('negocios/n1').set({
        'propietarioUid': 'u1',
        'slug': 'mi-tienda',
        'webActiva': true,
      });
      await firestore.doc('negocios_publicos/mi-tienda').set({
        'negocioId': 'n1',
      });
      await firestore.doc('negocios/n1/resumenes/2026-11-07').set({'v': 1});
      await firestore.doc('negocios/n1/productos/p1').set({'nombre': 'Pan'});
      // Datos de otro negocio: no se debe tocar nada.
      await firestore.doc('negocios/n2').set({
        'propietarioUid': 'u2',
        'slug': 'otra',
      });
      await firestore.doc('negocios/n2/pedidos/x').set({'negocioId': 'n2'});
      await firestore.doc('users/u2').set({'email': 'z@z.z'});
    });

    test('borra todo lo del negocio y del usuario, y nada de otros', () async {
      for (var i = 0; i < 3; i++) {
        await firestore.doc('negocios/n1/pedidos/p$i').set({
          'negocioId': 'n1',
          'cliente': {'nombre': 'Ana', 'telefono': '999'},
        });
      }

      await caso.ejecutar(uid: 'u1', negocioId: 'n1');

      for (final ruta in [
        'negocios/n1',
        'negocios_publicos/mi-tienda',
        'users/u1',
        'negocios/n1/pedidos/p0',
        'negocios/n1/pedidos/p2',
        'negocios/n1/resumenes/2026-11-07',
        'negocios/n1/productos/p1',
        'users/u1/plan/actual',
      ]) {
        expect((await firestore.doc(ruta).get()).exists, isFalse, reason: ruta);
      }
      expect(
        (await firestore.collection('negocios/n1/pedidos').get()).docs,
        isEmpty,
      );
      expect((await firestore.doc('negocios/n2').get()).exists, isTrue);
      expect(
        (await firestore.doc('negocios/n2/pedidos/x').get()).exists,
        isTrue,
      );
      expect((await firestore.doc('users/u2').get()).exists, isTrue);
      expect(accesoBorrado, isTrue);
    });

    test('borra más de un lote (850 pedidos) sin dejar ninguno', () async {
      for (var tanda = 0; tanda < 2; tanda++) {
        final lote = firestore.batch();
        for (var i = 0; i < 425; i++) {
          lote.set(firestore.doc('negocios/n1/pedidos/m${tanda}_$i'), {
            'negocioId': 'n1',
          });
        }
        await lote.commit();
      }

      await caso.ejecutar(uid: 'u1', negocioId: 'n1');

      expect(
        (await firestore.collection('negocios/n1/pedidos').get()).docs,
        isEmpty,
      );
    });

    test('repetirlo después de un corte no falla', () async {
      await caso.ejecutar(uid: 'u1', negocioId: 'n1');
      await caso.ejecutar(uid: 'u1', negocioId: 'n1');

      expect((await firestore.doc('users/u1').get()).exists, isFalse);
    });
  });
}
