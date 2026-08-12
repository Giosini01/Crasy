import 'dart:async';

import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/domain/repositories/auth_repository.dart';

/// Un'autenticazione finta, pilotabile dal test.
///
/// Sta qui e non dentro un file di test perche' la sessione e' il presupposto
/// di quasi tutto: senza, ogni prova che tocca il router o una schermata
/// dovrebbe ricrearsela identica.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.currentUser});

  final _controller = StreamController<AppUser?>.broadcast();

  @override
  AppUser? currentUser;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield currentUser;
    yield* _controller.stream;
  }

  void dispose() {
    _controller.close();
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> signUp({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    _controller.add(null);
  }
}
