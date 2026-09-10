import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';

class _FirebaseAuthMock extends Mock implements FirebaseAuth {}

class _UserCredentialMock extends Mock implements UserCredential {}

class _UserMock extends Mock implements User {}

void main() {
  test(
    'cierra la sesión si el registro encuentra una cuenta verificada',
    () async {
      final firebaseAuth = _FirebaseAuthMock();
      final credential = _UserCredentialMock();
      final user = _UserMock();
      final repository = AuthRepository(firebaseAuth: firebaseAuth);
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: 'ana@example.com',
          password: 'secreto',
        ),
      ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'ana@example.com',
          password: 'secreto',
        ),
      ).thenAnswer((_) async => credential);
      when(() => credential.user).thenReturn(user);
      when(() => user.emailVerified).thenReturn(true);
      when(() => firebaseAuth.signOut()).thenAnswer((_) async {});

      await expectLater(
        repository.registrarse(email: 'ana@example.com', password: 'secreto'),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'email-already-in-use',
          ),
        ),
      );

      verify(() => firebaseAuth.signOut()).called(1);
    },
  );
}
